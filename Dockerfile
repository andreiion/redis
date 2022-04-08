#FROM redis:6.2
FROM ubuntu:18.04

RUN apt-get update && apt-get install -y htop iproute2 iputils-ping tcpdump iproute2 iperf3

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
