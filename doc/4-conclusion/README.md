# 测试步骤

## **Client Configuration**


```
# Update system
yum update -y

# Install and start OpenvSwitch
yum install -y openvswitch
service openvswitch start

# Create bridge
ovs-vsctl add-br br-int

# Create VXLAN interface and set destination VTEP
ovs-vsctl add-port br-int vxlan0 -- set interface vxlan0 type=vxlan options:remote_ip=<server ip> options:key=10 options:dst_port=4789

# Create tenant namespaces
ip netns add tenant1

# Create veth pairs
ip link add host-veth0 type veth peer name host-veth1
ip link add tenant1-veth0 type veth peer name tenant1-veth1

# Link primary veth interfaces to namespaces
ip link set tenant1-veth0 netns tenant1

# Add IP addresses
ip a add dev host-veth0 192.168.0.10/24
ip netns exec tenant1 ip a add dev tenant1-veth0 192.168.10.10/24

# Bring up loopback interfaces
ip netns exec tenant1 ip link set dev lo up

# Set MTU to account for VXLAN overhead
ip link set dev host-veth0 mtu 8950
ip netns exec tenant1 ip link set dev tenant1-veth0 mtu 8950

# Bring up veth interfaces
ip link set dev host-veth0 up
ip netns exec tenant1 ip link set dev tenant1-veth0 up

# Bring up host interfaces and set MTU
ip link set dev host-veth1 up
ip link set dev host-veth1 mtu 8950
ip link set dev tenant1-veth1 up
ip link set dev tenant1-veth1 mtu 8950

# Attach ports to OpenvSwitch
ovs-vsctl add-port br-int host-veth1
ovs-vsctl add-port br-int tenant1-veth1

# Enable VXLAN offload
ethtool -k eth0 tx-udp_tnl-segmentation on
ethtool -k eth1 tx-udp_tnl-segmentation on
```


## **Server Configuration**


```
# Update system
yum update -y

# Install and start OpenvSwitch
yum install -y openvswitch
service openvswitch start

# Create bridge
ovs-vsctl add-br br-int

# Create VXLAN interface and set destination VTEP
ovs-vsctl add-port br-int vxlan0 -- set interface vxlan0 type=vxlan options:remote_ip=<client ip> options:key=10 options:dst_port=4789

# Create tenant namespaces
ip netns add tenant1

# Create veth pairs
ip link add host-veth0 type veth peer name host-veth1
ip link add tenant1-veth0 type veth peer name tenant1-veth1

# Link primary veth interfaces to namespaces
ip link set tenant1-veth0 netns tenant1

# Add IP addresses
ip a add dev host-veth0 192.168.0.20/24
ip netns exec tenant1 ip a add dev tenant1-veth0 192.168.10.20/24

# Bring up loopback interfaces
ip netns exec tenant1 ip link set dev lo up

# Set MTU to account for VXLAN overhead
ip link set dev host-veth0 mtu 8950
ip netns exec tenant1 ip link set dev tenant1-veth0 mtu 8950

# Bring up veth interfaces
ip link set dev host-veth0 up
ip netns exec tenant1 ip link set dev tenant1-veth0 up

# Bring up host interfaces and set MTU
ip link set dev host-veth1 up
ip link set dev host-veth1 mtu 8950
ip link set dev tenant1-veth1 up
ip link set dev tenant1-veth1 mtu 8950

# Attach ports to OpenvSwitch
ovs-vsctl add-port br-int host-veth1
ovs-vsctl add-port br-int tenant1-veth1

# Enable VXLAN offload
ethtool -k eth0 tx-udp_tnl-segmentation on
ethtool -k eth1 tx-udp_tnl-segmentation on
```



## **Offload verification**


```
[root@client ~]# dmesg | grep VxLAN
[ 6829.318535 ] be2net 0000:05:00.0: Enabled VxLAN offloads for UDP port 4789
[ 6829.324162 ] be2net 0000:05:00.1: Enabled VxLAN offloads for UDP port 4789
[ 6829.329787 ] be2net 0000:05:00.2: Enabled VxLAN offloads for UDP port 4789
[ 6829.335418 ] be2net 0000:05:00.3: Enabled VxLAN offloads for UDP port 4789

[root@client ~]# ethtool -k eth0 | grep tx-udp
tx-udp_tnl-segmentation: on

[root@server ~]# dmesg | grep VxLAN
[ 6829.318535 ] be2net 0000:05:00.0: Enabled VxLAN offloads for UDP port 4789
[ 6829.324162 ] be2net 0000:05:00.1: Enabled VxLAN offloads for UDP port 4789
[ 6829.329787 ] be2net 0000:05:00.2: Enabled VxLAN offloads for UDP port 4789
[ 6829.335418 ] be2net 0000:05:00.3: Enabled VxLAN offloads for UDP port 4789

[root@server ~]# ethtool -k eth0 | grep tx-udp
tx-udp_tnl-segmentation: on
```

## **TCP stream testing**


```
#!/bin/sh
#
# This is an example script for using netperf. Feel free to modify it 
# as necessary, but I would suggest that you copy this one first.
# 
# This version has been modified to take advantage of the confidence
# interval support in revision 2.0 of netperf. it has also been altered
# to make submitting its resutls to the netperf database easier
#
# usage: ./netperf_tcp_stream.sh [machine A's IP] [CPU] [-Tx,x] > filename.txt
#

if [ $# -gt 4 ]; then
  echo "try again, correctly -> tcp_stream_script hostname [CPU] [-Tx,x] [I]"
  exit 1
fi

if [ $# -eq 0 ]; then
  echo "try again, correctly -> tcp_stream_script hostname [CPU]"
  exit 1
fi

# where the programs are
NETHOME=/usr/local/bin
#NETHOME="/opt/netperf"
#NETHOME=.

# at what port will netserver be waiting? If you decide to run
# netserver at a different port than the default of 12865, then set
# the value of PORT apropriately
#PORT="-p some_other_portnum"
PORT=""

# The test length in seconds
TEST_TIME=5

# How accurate we want the estimate of performance: 
#      maximum and minimum test iterations (-i)
#      confidence level (99 or 95) and interval (percent)
STATS_STUFF="-i 10,2 -I 99,5"

# The socket sizes that we will be testing
SOCKET_SIZES="128K 57344 32768 8192 4M"

# The send sizes that we will be using
SEND_SIZES="4096 8192 32768"

# if there are two parms, parm one it the hostname and parm two will
# be a CPU indicator. actually, anything as a second parm will cause
# the CPU to be measured, but we will "advertise" it should be "CPU"

if [ $# -eq 4 ]; then
  REM_HOST=$1
  LOC_CPU=""
  REM_CPU=""
  STREAM="TCP_STREAM"

case $2 in
\CPU) LOC_CPU="-c";REM_CPU="-C";;
\I) STREAM="TCP_MAERTS";;
esac

case $3 in
\CPU) LOC_CPU="-c";REM_CPU="-C";;
\I) STREAM="TCP_MAERTS";;
esac

case $4 in
\CPU) LOC_CPU="-c";REM_CPU="-C";;
\I) STREAM="TCP_MAERTS";;
esac
fi

if [ $# -eq 3 ]; then
  REM_HOST=$1
  LOC_CPU=""
  REM_CPU=""
  STREAM="TCP_STREAM"

case $2 in
\CPU) LOC_CPU="-c";REM_CPU="-C";;
\I) STREAM="TCP_MAERTS";;
esac

case $3 in
\CPU) LOC_CPU="-c";REM_CPU="-C";;
\I) STREAM="TCP_MAERTS";;
esac
fi

if [ $# -eq 2 ]; then
  REM_HOST=$1
  LOC_CPU=""
  REM_CPU=""
  STREAM="TCP_STREAM"

case $2 in
\CPU) LOC_CPU="-c";REM_CPU="-C";;
\I) STREAM="TCP_MAERTS";;
esac
fi

if [ $# -eq 1 ]; then
  REM_HOST=$1
  LOC_CPU=""
  REM_CPU=""
  STREAM="TCP_STREAM"
fi

# If we are measuring CPU utilization, then we can save beaucoup
# time by saving the results of the CPU calibration and passing
# them in during the real tests. So, we execute the new CPU "tests"
# of netperf and put the values into shell vars.
case $LOC_CPU in
\-c) LOC_RATE=`$NETHOME/netperf $PORT -t LOC_CPU`;;
*) LOC_RATE=""
esac

case $REM_CPU in
\-C) REM_RATE=`$NETHOME/netperf $PORT -t REM_CPU -H $REM_HOST`;;
*) REM_RATE=""
esac

# this will disable headers
NO_HDR="-P 0"
for SOCKET_SIZE in $SOCKET_SIZES
  do
  for SEND_SIZE in $SEND_SIZES
    do
    echo
    echo ------------------------------------
    echo
    # we echo the command line for cut and paste 
    echo $NETHOME/netperf $PORT -l $TEST_TIME -H $REM_HOST -t $STREAM\
         $LOC_CPU $LOC_RATE $REM_CPU $REM_RATE -c -C $STATS_STUFF --\
         -m $SEND_SIZE -s $SOCKET_SIZE -S $SOCKET_SIZE 

    echo
    # since we have the confidence interval stuff, we do not
    # need to repeat a test multiple times from the shell
    $NETHOME/netperf $PORT -l $TEST_TIME -H $REM_HOST -t $STREAM\
    $LOC_CPU $LOC_RATE $REM_CPU $REM_RATE -c -C $STATS_STUFF --\
    -m $SEND_SIZE -s $SOCKET_SIZE -S $SOCKET_SIZE 

   done
  done
```


## **UDP stream testing**

```
#!/bin/sh
#
# This is an example script for using netperf. Feel free to modify it 
# as necessary, but I would suggest that you copy this one first.
# This script performs various UDP unidirectional stream tests.
# usage: ./netperf_udp_stream.sh [machine A's IP] [CPU] [-Tx,x] > filename.txt
#

if [ $# -gt 4 ]; then
  echo "try again, correctly -> udp_stream_script hostname [CPU] [-Tx,x] [I]"
  exit 1
fi

if [ $# -eq 0 ]; then
  echo "try again, correctly -> udp_stream_script hostname [CPU]"
  exit 1
fi

# where the programs are

NETHOME=/usr/local/bin
#NETHOME="/opt/netperf"
#NETHOME="."

# at what port will netserver be waiting? If you decide to run
# netserver at a differnet port than the default of 12865, then set
# the value of PORT apropriately
#PORT="-p some_other_portnum"
PORT=""

# The test length in seconds
TEST_TIME=5

# How accurate we want the estimate of performance: 
#      maximum and minimum test iterations (-i)
#      confidence level (99 or 95) and interval (percent)

STATS_STUFF="-i 10,2 -I 99,10"

# The socket sizes that we will be testing. This should be a list of
# integers separated by spaces

SOCKET_SIZES="32768 4M"

# The send sizes that we will be using. Using send sizes that result
# in UDP packets which are larger than link size can be a bad thing to do.
# for FDDI, you can tack-on a 4096 data point

SEND_SIZES="64 1024 1472"

# if there are two parms, parm one it the hostname and parm two will
# be a CPU indicator. actually, anything as a second parm will cause
# the CPU to be measured, but we will "advertise" it should be "CPU"

if [ $# -eq 4 ]; then
  REM_HOST=$1
  LOC_CPU=""
  REM_CPU=""
  STREAM="UDP_STREAM"

case $2 in
\CPU) LOC_CPU="-c";REM_CPU="-C";;
\I) STREAM="UDP_MAERTS";;
esac

case $3 in
\CPU) LOC_CPU="-c";REM_CPU="-C";;
\I) STREAM="UDP_MAERTS";;
esac

case $4 in
\CPU) LOC_CPU="-c";REM_CPU="-C";;
\I) STREAM="UDP_MAERTS";;
esac
fi

if [ $# -eq 3 ]; then
  REM_HOST=$1
  LOC_CPU=""
  REM_CPU=""
  STREAM="UDP_STREAM"

case $2 in
\CPU) LOC_CPU="-c";REM_CPU="-C";;
\I) STREAM="UDP_MAERTS";;
esac

case $3 in
\CPU) LOC_CPU="-c";REM_CPU="-C";;
\I) STREAM="UDP_MAERTS";;
esac
fi

if [ $# -eq 2 ]; then
  REM_HOST=$1
  LOC_CPU=""
  REM_CPU=""
  STREAM="UDP_STREAM"

case $2 in
\CPU) LOC_CPU="-c";REM_CPU="-C";;
\I) STREAM="UDP_MAERTS";;
esac
fi

if [ $# -eq 1 ]; then
  REM_HOST=$1
  LOC_CPU=""
  REM_CPU=""
  STREAM="UDP_STREAM"
fi

# If we are measuring CPU utilization, then we can save beaucoup
# time by saving the results of the CPU calibration and passing
# them in during the real tests. So, we execute the new CPU "tests"
# of netperf and put the values into shell vars.
case $LOC_CPU in
\-c) LOC_RATE=`$NETHOME/netperf $PORT -t LOC_CPU`;;
*) LOC_RATE=""
esac

case $REM_CPU in
\-C) REM_RATE=`$NETHOME/netperf $PORT -t REM_CPU -H $REM_HOST`;;
*) REM_RATE=""
esac

# This will tell netperf that headers are not to be displayed
NO_HDR="-P 0"

for SOCKET_SIZE in $SOCKET_SIZES
do
  for SEND_SIZE in $SEND_SIZES
  do
    echo
    echo ------------------------------------------------------
    echo Testing with the following command line:
    echo $NETHOME/netperf $PORT -l $TEST_TIME -H $REM_HOST $STATS_STUFF \
           $LOC_CPU $LOC_RATE $REM_CPU $REM_RATE -c -C -t $STREAM -- \
           -m $SEND_SIZE -s $SOCKET_SIZE -S $SOCKET_SIZE 

    $NETHOME/netperf $PORT -l $TEST_TIME -H $REM_HOST $STATS_STUFF \
      $LOC_CPU $LOC_RATE $REM_CPU $REM_RATE -c -C -t $STREAM -- \
      -m $SEND_SIZE -s $SOCKET_SIZE -S $SOCKET_SIZE 

  done
done
echo
```

