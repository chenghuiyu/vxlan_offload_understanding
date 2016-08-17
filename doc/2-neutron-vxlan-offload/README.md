# 二、neutron中的VXLAN offload实现原理

---
Neutron中使用网卡VXLAN的offload技术两种场景，一种是Linux bridge，另外一种就是OVS场景下的应用，之所以考虑这两种场景主要从以下方面考虑：

**（1）Linux bridge**：这里的主要是指openstack中单独使用Linux bridge agent，即Linux bridge+VXLAN的情况，OVS其实还存在一些稳定性的问题，比如Kernetl panics 1.10、ovs-switched segfaults 1.11、广播风暴和Data corruption 2.01等，这是社区里提及到的地方。这里主要考虑的是针对NIC VXLAN offload的操作方式的区别。


**（2）OVS**：这种情景就是使用OVS agent的情况，结合NIC VXLAN的offload进行具体的分析。


## **2.1 Neutron VXLAN + Linux bridge中的NIC VXLAN offload**

将这一场景分为不启动网卡的VXLAN offload和启动网卡的VXLAN offload两种情况，并对内部的实现机制的不同进行对比分析。

### **（一）网卡不开启VXLAN offload**
![1](resources/1.PNG)


#### **计算节点**

从图上可以看出，网包在计算节点需要进行两个方面的考虑，从虚机内部出去的数据包以及进入虚机的数据包。

- **虚机内部出去的数据包**

（1）虚机发出的二层帧数据包首先经过tap设备发送到Linux bridge进行处理；

（2）Linux bridge收到tap设备的二层帧后交给与其连接的VXLAN interface；

（3）VXLAN interface先对二层帧进行检查，看是否超过预先设定的值，如果超过大小就会进行分片处理，接着二层帧数据包会被Linux VXLAN kernel模块的注册的hook函数进行处理，扔给Linux VETP kernel模块；

（4）Linux VETP kernel模块的vxlan_xmit函数先判断是否需要进行ARP广播，然后就会将二层数据帧封装成udp package，然后调用系统接口处理；

（5）系统函数利用udp sockegt发送出VXLAN封装后的数据包，直接扔给网卡，经过网卡发送到外面去。

- **进入虚机的数据包**

（1） 在计算节点，进入虚机的数据包首先经过网卡，在满足MTU的情况下，网卡将数据包交给UDP Socket进行处理，并给到Linux VTEP kernel里去；

（2）Linux VXLAN kernel模块在udp协议栈上注册hook函数，该函数对接收到的数据帧做简单检查，再交给内核模块中专门处理VXLAN的函数vxlan_rcv；

（3）函数vxlan_rcv先判断该VXLAN的数据包是否存在VNI号，然后就进行VXLAN的数据包的解包，接着就调用系统接口，将解包后的二层帧数据扔到VXLAN interface；

（4）VXLAN interface需要重新计算MTU的大小，如果超过预定的设置后，就会对二层帧数据包进行分片，接着将帧数据扔给Linux bridge，进行正常的数据包的转发；

（5）Linux bridge收到二层帧数据包后转发给桥上的tap设备，tap设备再将网包扔给所连接的虚机的tap接口，最终到达虚机。


#### **网络节点**

在网络节点转发的数据包也分为两个方向


- **发送到外网的数据包**

（1） 在网络节点，发往外网的数据包首先经过网卡，在满足预先设定的MTU的情况下，网卡将数据包交给UDP Socket进行处理，并给到Linux VTEP kernel里去；

（2）Linux VXLAN kernel模块在udp协议栈上注册hook函数，该函数对接收到的数据帧做简单检查，再交给内核模块中专门处理VXLAN的函数vxlan_rcv；

（3）函数vxlan_rcv先判断该VXLAN的数据包是否存在VNI号，然后就进行VXLAN的数据包的解包，接着就调用系统接口，将解包后的二层帧数据扔到VXLAN interface；

（4）VXLAN interface需要重新计算MTU的大小，如果超过预定的设置后，就会对二层帧数据包进行分片，接着将帧数据扔给Linux bridge，进行正常的数据包的转发；

（5）Linux bridge收到二层帧数据包后转发给桥上的tap设备，tap设备再将网包扔给所连接的router的qr接口，route利用NAT转换将数据包通过qg接口扔给br-ex网桥；

（6）br-ex网桥接收到网包后通过网口ethX发送到外网去；

- **从外网进来的数据包**

（1）外网过来的数据包先经过router，router根据分配给虚机的floating ip，将数据包扔给Linux bridge；

（2）Linux bridge收到tap设备的二层帧后交给与其连接的VXLAN interface；

（3）VXLAN interface先对二层帧进行检查，看是否超过预先设定的值，如果超过大小就会进行分片处理，接着二层帧数据包会被Linux VXLAN kernel模块的注册的hook函数进行处理，扔给Linux VETP kernel模块；

（4）Linux VETP kernel模块的vxlan_xmit函数先判断是否需要进行ARP广播，然后就会将二层数据帧封装成udp package，然后调用系统接口处理；

（5）系统函数利用udp sockegt发送出VXLAN封装后的数据包，直接扔给网卡，经过网卡发送到外面去


### **（二）网卡开启VXLAN offload**


#### **计算节点**

从图上可以看出，网包在计算节点需要进行两个方面的考虑，从虚机内部出去的数据包以及进入虚机的数据包。

- **虚机内部出去的数据包**

（1）虚机发出的二层帧数据包首先经过tap设备发送到Linux bridge进行处理；

（2）Linux bridge接受tap设备的二层帧数据包，扔给启动VXLAN offload功能的网卡NIC；

（3）NIC在满足预定大小的MTU条件下，直接对二层帧数据包进行VXLAN的offload处理，并把带有VXLAN header的数据包扔给leaf交换机，如果超过了MTU，先对网包进行分片再进行处理；



- **进入虚机的数据包**

（1） 在计算节点，从leaf交换机进入虚机的数据包首先经过网卡NIC，在满足MTU的情况下，对带有VXLAN header的网包进行VXLAN的offload，如果网络包大小超过了MTU，那么NIC利用TSO或者USO对网包进行分片处理；

（2）经过NIC处理后的二层帧数据包直接扔给Linux bridge进行处理；

（3）Linux bridge收到二层帧数据包后转发给桥上的tap设备，tap设备再将网包扔给所连接的虚机的tap接口，最终到达虚机。

#### **网络节点**

在网络节点转发的数据包也分为两个方向

- **发送到外网的数据包**

（1） 在网络节点，发往外网的数据包首先从leaf交换机进入虚机的数据包首先经过网卡NIC，在满足MTU的情况下，对带有VXLAN header的网包进行VXLAN的offload，如果网络包大小超过了MTU，那么NIC利用TSO或者USO对网包进行分片处理；

（2）经过NIC处理后的二层帧数据包直接扔给Linux bridge进行处理；

（3）Linux bridge收到二层帧数据包后转发给桥上的tap设备，tap设备再将网包扔给所连接的router的qr接口，route利用NAT转换将数据包通过qg接口扔给br-ex网桥；

（4）br-ex网桥接收到网包后通过网口ethX发送到外网去；

- **从外网进来的数据包**

（1）外网过来的数据包先经过router，router根据分配给虚机的floating ip，将数据包扔给Linux bridge；

（2）Linux bridge接受tap设备的二层帧数据包，扔给启动VXLAN offload功能的网卡NIC；

（3）NIC在满足预定大小的MTU条件下，直接对二层帧数据包进行VXLAN的offload处理，并把带有VXLAN header的数据包扔给leaf交换机，如果超过了MTU，先对网包进行分片再进行处理；


## **2.2 Neutron VXLAN +openVswitch中的NIC VXLAN offload**

   在这种场景下也可以分为两种情况进行讨论，NIC不开启VXLAN offload和开启VXLAN offload，对于不开启VXLAN offload的情况，即为传统上neutron的VXLAN的实现方案，具体[参见这里](http://chyufly.github.io/blog/2016/07/11/understanding-neutron-vlan-vxlan/)，下面主要介绍NIC在开启VXLAN offload情况下的网络数据通信机制。也是将网包分为两个方向进行说明，一种是网络数据包从虚机发出，另外一种就是网络数据包从外面发送到虚机里面去。


### **计算节点**

#### **Linux bridge和br-int**

  在计算节点上，OVS的br-int主要进行vlan标签的设置和转发，而开启VXLAN offload功能的NIC主要用于vxlan标签的设置和转发流量。

  在OVS中，利用网桥br-int来对vlan和mac进行转发，作为一个二层交换机使用，主要的接口包含两类：linux bridge过来的qvo-xxx以及往外的patch-tun接口，连接到br-tun
网桥。这样就可以通过qvo-xxx 接口上为每个经过的网络分配一个内部 vlan的tag，如果在同一个neutron网络里启动了多台虚机，那么它们的tag都是一样的，如果是在不同的网络，那么vlan tag就会不一样。

如下图所示，如果br-int从port号17进入的网包，就会打上VLAN tag为8，直接发送到NIC上去，如果网包带有VLAN tag为8，则直接从port口17出去。

#### **NIC的VXLAN offload**

neutron中的vxlan的offload主要在NIC中完成，利用NIC driver实现带有VXLAN header的网包在leaf交换机上进行正常的转发，可以从两个维度来进行思考：

（1）从vm内部过来的数据包从br-int网桥过来，NIC对数据包进行VXLAN header处理，并将处理后的udp package扔给连接的leaf交换机；

（2）数据包从外面public network经过leaf交换机过来的VXLAN的网络包，首先判断该VXLAN的数据包是否存在VNI号，然后就进行VXLAN的数据包的解包，将解包后的二层帧数
据扔到br-int上去；

### **网络节点**

在网络节点上，所部署的neutron服务主要包括DHCP服务和路由服务等，网桥主要包括OVS的br-int，Linux bridge和br-ex等。


#### **NIC的VXLAN offload**

网络节点的VXLAN的offload主要由NIC来实现，主要实现udp package的封装和解封，可以从两个维度来进行思考：

（1）从虚机内部经过leaf交换机过来的VXLAN的网络包，首先判断该VXLAN的数据包是否存在VNI号，然后就进行VXLAN的数据包的解包，将解包后的二层帧数据扔到br-int上去
；

（2）二层帧数据包从br-int网桥过来，NIC对数据包进行VXLAN header处理，并将处理后的udp package扔给连接的leaf交换机。


#### **Linux bridge和br-int**

   在controller节点上，vlan tag的设置主要在br-int网桥上进行，作为一个正常的二层交换设备进行使用，只是根据vlan和mac进行数据包的转发。接口类型包括：

（1）tap-xxx，连接到网络 DHCP 服务的命名空间；

（2）qr-xxx，连接到路由服务的命名空间；

（3）patch-tun 接口，连接到 br-tun 网桥。

  如图所示，如果br-int从qr-XXX进入的网包，就会打上VLAN tag为15，发送到br-tun上去，如果网包带有VLAN tag为15，则直接从qr-XXX口进到router服务中去。主要通过br-ex网桥和public network进行通信，一个是挂载的物理接口上，如 ens160，网包将从这个接口发送到外部网络上。

  另外一个是 qg-xxx 这样的接口，是连接到 router 服务的网络名字空间中，里面绑定一个路由器的外部 IP，作为 NAT 时候的地址，另外，网络中的 floating IP 也放在这个网络名字空间中。



#### **router和DHCP**

   dhcp服务是通过dnsmasq进程（轻量级服务器，可以提供dns、dhcp、tftp等服务）来实现的，该进程绑定到dhcp名字空间中的br-int的接口上。neutron中的路由服务主要
提供跨子网间的网络通信，包括虚拟想访问外部网络等。路由服务主要利用namespace实现不同网络之间的隔离性。另外，router还可以实现tenant work和external network之间的网络连接，通过SNAT实现tenant network往external network的网络连通性（fixed IP），通过DNAT实现external network往tenant network的网络连通性（floating IP）。

