# 三、 VXLAN offload性能验证方案

--------

####  **特别说明：由于目前实际生产环境的网卡不具备VXLAN的offload功能，所以无法进行对比性能测试，后续如果环境满足再进行对比分析验证，该部分主要介绍后续验证的设计方案和步骤。**


## **3.1 测试整体概述**


#### **网包流向**

| Traffic Flow Type         | Data Path                                                                                                    | 
| --------------------------| ----------------------------------------------------------------------------------------------------------   | 
|VXLAN-to-VXLAN over bridge | client host -> linux bridge -> br-int -> eth1 -> leaf switch -> eth1 -> br-int -> linux bridge -> server host|   


#### **整体原理框图**

![1](resources/experience.png)

## **3.2 测试验证步骤**

Netperf工具主要用来产生客户端和服务端的TCP流量，它是测试网络的一个轻量级的用户进程，主要包括以下部分：

Netperf---用户级进程，用来连接服务端并产生流量

Netserver---用户级进程，用来监听个接受请求连接。


查看offload信息

```
[root@node-1 vxlan-offload]$ ethtool -k ethX
Features for eno16777736:
rx-checksumming: off
tx-checksumming: on
        tx-checksum-ipv4: off [fixed]
		tx-checksum-ip-generic: on
        tx-checksum-ipv6: off [fixed]
		tx-checksum-fcoe-crc: off [fixed]
		tx-checksum-sctp: off [fixed]
scatter-gather: on
        tx-scatter-gather: on
		tx-scatter-gather-fraglist: off [fixed]
tcp-segmentation-offload: on
        tx-tcp-segmentation: on
		tx-tcp-ecn-segmentation: off [fixed]
		tx-tcp6-segmentation: off [fixed]
udp-fragmentation-offload: off [fixed]
generic-segmentation-offload: on
generic-receive-offload: on
large-receive-offload: off [fixed]
rx-vlan-offload: on
tx-vlan-offload: on [fixed]
ntuple-filters: off [fixed]
receive-hashing: off [fixed]
highdma: off [fixed]
rx-vlan-filter: on [fixed]
vlan-challenged: off [fixed]
tx-lockless: off [fixed]
netns-local: off [fixed]
tx-gso-robust: off [fixed]
tx-fcoe-segmentation: off [fixed]
tx-gre-segmentation: off [fixed]
tx-ipip-segmentation: off [fixed]
tx-sit-segmentation: off [fixed]
tx-udp_tnl-segmentation: off [fixed]  //该选项的状态代表着网卡的VXLAN offload功能
tx-mpls-segmentation: off [fixed]
fcoe-mtu: off [fixed]
tx-nocache-copy: off
loopback: off [fixed]
rx-fcs: off
rx-all: off
tx-vlan-stag-hw-insert: off [fixed]
rx-vlan-stag-hw-parse: off [fixed]
rx-vlan-stag-filter: off [fixed]
busy-poll: off [fixed]

```



可以看到启动VXLAN offload功能的tx-udp_tnl-segmentation带有[fixed]，意味这VXLAN的offload功能不可用，目前该网卡并不支持VXLAN的offload功能。

### **验证测试：**

Netperf可以用来获取client端和server端的throughput和CPU的利用率，网络的吞吐量，建立时间等方面，测试内容主要是用于测试eth网卡的VXLAN offload的性能，后续的测试项可以按照下面表格中的参数进行测试，分为两种情况，即**开启NIC的VXLAN offload功能**和**不开启NIC的VXLAN offload功能**。


| socket发送与接收缓存大小|client向server端发送测试分组的大小|client端CPU利用率|server端CPU利用率|网络吞吐量|网络响应时间|
|-------------------------|--------------------------------- |-----------------|-----------------|--------- |------------|
|128K                     |4K                                |--               |--               |--        |--          |
|128K                     |8K                                |--               |--               |--        |--          |
|128K                     |32K                               |--               |--               |--        |--          |
|56K                      |4K                                |--               |--               |--        |--          |
|56K                      |8K                                |--               |--               |--        |--          |
|56K                      |32K                               |--               |--               |--        |--          |
|32K                      |4K                                |--               |--               |--        |--          |
|32K                      |8K                                |--               |--               |--        |--          |
|32K                      |32K                               |--               |--               |--        |--          |
|4M                       |4K                                |--               |--               |--        |--          |
|4M                       |8K                                |--               |--               |--        |--          |
|4M                       |32K                               |--               |--               |--        |--          |

#### **相关shell测试脚本已列出：**

[TCP stream testing](https://github.com/chenghuiyu/vxlan_offload_understanding/tree/master/shell/netperf_tcp_stream.sh)

[UDP stream testing](https://github.com/chenghuiyu/vxlan_offload_understanding/tree/master/shell/netperf_udp_stream.sh)


