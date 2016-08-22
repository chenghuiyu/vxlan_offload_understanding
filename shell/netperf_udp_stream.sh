#!/bin/sh

if [ $# -gt 4 ]; then
  echo "try again, correctly -> udp_stream_script hostname [CPU] [-Tx,x] [I]"
  exit 1
fi

if [ $# -eq 0 ]; then
  echo "try again, correctly -> udp_stream_script hostname [CPU]"
  exit 1
fi

# netperf安装路径
NETHOME=/usr/local/bin

# 默认监听端口12865
PORT=""

# 监听的时间
TEST_TIME=5


STATS_STUFF="-i 10,2 -I 99,10"


# 发送端和接收端socket缓冲大小
SOCKET_SIZES="32768 4M"


# client往server端发送数据包的大小
SEND_SIZES="64 1024 1472"


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

case $LOC_CPU in
\-c) LOC_RATE=`$NETHOME/netperf $PORT -t LOC_CPU`;;
*) LOC_RATE=""
esac

case $REM_CPU in
\-C) REM_RATE=`$NETHOME/netperf $PORT -t REM_CPU -H $REM_HOST`;;
*) REM_RATE=""
esac

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
