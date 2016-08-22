#!/bin/sh

if [ $# -gt 4 ]; then
  echo "try again, correctly -> tcp_stream_script hostname [CPU] [-Tx,x] [I]"
  exit 1
fi

if [ $# -eq 0 ]; then
  echo "try again, correctly -> tcp_stream_script hostname [CPU]"
  exit 1
fi

# netperf安装路径
NETHOME=/usr/local/bin


# 默认端口为12865
PORT=""

# 测试时间
TEST_TIME=5

STATS_STUFF="-i 10,2 -I 99,5"

# 发送端和接收端的socket缓冲大小
SOCKET_SIZES="128K 57344 32768 8192 4M"

# client端发送给server端的数据包的大小
SEND_SIZES="4096 8192 32768"


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

case $LOC_CPU in
\-c) LOC_RATE=`$NETHOME/netperf $PORT -t LOC_CPU`;;
*) LOC_RATE=""
esac

case $REM_CPU in
\-C) REM_RATE=`$NETHOME/netperf $PORT -t REM_CPU -H $REM_HOST`;;
*) REM_RATE=""
esac

# VXLAN headers设置
NO_HDR="-P 0"
for SOCKET_SIZE in $SOCKET_SIZES
  do
  for SEND_SIZE in $SEND_SIZES
    do
    echo
    echo ------------------------------------
    echo
    echo $NETHOME/netperf $PORT -l $TEST_TIME -H $REM_HOST -t $STREAM\
         $LOC_CPU $LOC_RATE $REM_CPU $REM_RATE -c -C $STATS_STUFF --\
         -m $SEND_SIZE -s $SOCKET_SIZE -S $SOCKET_SIZE 

    echo
    $NETHOME/netperf $PORT -l $TEST_TIME -H $REM_HOST -t $STREAM\
    $LOC_CPU $LOC_RATE $REM_CPU $REM_RATE -c -C $STATS_STUFF --\
    -m $SEND_SIZE -s $SOCKET_SIZE -S $SOCKET_SIZE 

   done
  done
