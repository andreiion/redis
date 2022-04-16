#FROM redis:6.2
FROM ubuntu:20.04

<<<<<<< HEAD
RUN apt-get update && apt-get install -y apt-utils less vim htop iproute2 iputils-ping tcpdump iproute2 iperf3 linux-headers-$(uname -r) linux-tools-$(uname -r) bpfcc-tools build-essential
=======
RUN apt-get update && apt-get install -y apt-utils less vim htop iproute2 iputils-ping tcpdump iproute2 iperf3 linux-headers-$(uname -r) linux-tools-$(uname -r) bpfcc-tools
>>>>>>> 73e20a4c51b1aab328652bdaf93a0cf5b194706a

COPY redis-server /usr/local/bin/redis-server
COPY redis-cli /usr/local/bin/redis-cli
COPY redis-benchmark /usr/local/bin/redis-benchmark
COPY redis_server_6379.conf /etc/redis/redis_server_6379.conf
COPY redis_server_6380.conf /etc/redis/redis_server_6380.conf
COPY redis_server_6381.conf /etc/redis/redis_server_6381.conf

#ENTRYPOINT ["redis-server"]
#CMD ["/etc/redis/redis_server_6379.conf"]
#CMD ["/etc/redis/redis_server_6379.conf --loglevel debug"]
CMD ["redis-server"]
