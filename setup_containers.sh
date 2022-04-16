#!/bin/bash

docker_path="/home/eadinno/redis-docker/"

function deploy_master_slave_containers() {
    sudo docker rm -f redis_6380 redis_6379 redis_6381
    sudo docker build --file Dockerfile . --tag redis_compr

    sudo docker run --cap-add=ALL -d --network redis-bridge --name redis_6379 redis_compr redis-server \
                    /etc/redis/redis_server_6379.conf --loglevel debug
    sudo docker run --cap-add=ALL -d --network redis-bridge --name redis_6380 redis_compr redis-server \
                    /etc/redis/redis_server_6380.conf --loglevel debug

    #sudo docker run --cap-add=NET_ADMIN -d --network redis-bridge --name redis_6379 redis_compr redis-server \
    #                /etc/redis/redis_server_6379.conf --loglevel debug
    #sudo docker run --cap-add=NET_ADMIN -d --network redis-bridge --name redis_6380 redis_compr redis-server \
    #                /etc/redis/redis_server_6380.conf --loglevel debug

    #Connect another bridge to the interface so that we can call redis-benchmark and redis-cli outside the containers without speed limitations
    sudo docker network connect bridge redis_6379
    #sudo docker network connect redis-bridge redis_6379
    #sudo docker network connect redis-bridge redis_6380
    #sudo docker network disconnect bridge redis_6380

    # Ratelimit both containers. Seems like the tc command only limits egress, so thus we need to add the limit to the master
    #sudo docker exec redis_6379 tc qdisc add dev eth0 root tbf rate 1gbit burst 5000000 limit 15000000
    #sudo docker exec redis_6380 tc qdisc add dev eth0 root tbf rate 1gbit burst 5000000 limit 15000000

    # Setup the real-data container
    echo "Load Real Data to Redis"
    run_real_data_redis
}

function run_real_data_redis()
{
    sudo docker run --cap-add=ALL -d --network redis-bridge --name redis_6381 redis_compr redis-server \
                    /etc/redis/redis_server_6381.conf --loglevel debug

    sudo docker network connect bridge redis_6381
    sudo docker cp /home/eadinno/redis-docker/dump.rdb redis_6381:/dump.rdb
    sudo docker restart redis_6381
}

function load_real_data_redis() {
    sudo docker exec redis_6381 rm /dump.rdb
    #sudo docker exec redis_6380 rm /dump.rdb
    #sudo docker exec redis_6379 redis-cli -a redis save
    sudo docker cp /home/eadinno/redis-docker/dump.rdb redis_6379:/dump.rdb
    redis-cli -a redis -h 172.18.0.4 flushall
    sudo docker restart redis_6379
}

main () {

    cd $docker_path && deploy_master_slave_containers
}

main
