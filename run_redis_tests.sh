#!/bin/bash

clients_num=8

SLEEP_BETWEEN_SMALL_DATA=2

redis_bridge_device_ip="172.18.0.2"
docker_bridge_device_ip="172.17.0.2"

requests_num="200000"
data_size="10000"
tests="set"

declare -a compression_types=("no" "lzf" "lz4")

function set_compression_type() {
    local compression_type=$1
    redis-cli -a redis -h $redis_bridge_device_ip -p 6379 CONFIG SET replica-output-buffer-compression $compression_type 2> /dev/null
}

function get_replica_offset() {
    local replica_offset=$(redis-cli -a redis -h $redis_bridge_device_ip info replication 2> /dev/null | grep slave0 | awk -F , '{print $4}' | awk -F = '{print $2}')
    echo "$replica_offset"
}

function get_master_offset() {
    local master_offset=$(redis-cli -a redis -h $redis_bridge_device_ip info replication 2> /dev/null | grep master_repl_offset | awk -F : '{print $2}' | tr -d '\n\r' )
    echo "$master_offset"
}

function get_slave_state() {
    local STATUS=$(redis-cli -a redis -h $redis_bridge_device_ip info replication 2> /dev/null | grep slave0 | awk -F , '{print $3}' | awk -F = '{print $2}')
    echo "$STATUS"
}

function get_max_mem_used() {
    local max_mem_used=$(redis-cli -a redis -h $redis_bridge_device_ip info replication 2> /dev/null | grep max_mem_used | awk -F = '{print $2}' | tr -d '\n\r')
    echo "$max_mem_used"
}

function add_output_buffer_random_data() {
    echo "Add random data"
    redis-benchmark -h $docker_bridge_device_ip -t $tests -c $clients_num -n $requests_num -d $data_size -q -a redis -r 1000000000 --random-data 1 &
}

function add_output_buffer_compressable_data() {
    echo "Add compressable data"
    redis-benchmark -h $docker_bridge_device_ip -t $tests -c $clients_num -n $requests_num -d $data_size -q -a redis -r 1000000000 --random-data 0 &
}

add_output_buffer_real_data() {
     echo "Add real data"
    #redis-benchmark -h 172.17.0.2 -p 6379 -a redis -t real_data_string
    redis-benchmark -h $docker_bridge_device_ip -a redis -t real_data_string &
}

function flush_db() {
    echo "Flushing old DB data"
    redis-cli -a redis -h $redis_bridge_device_ip flushall 2> /dev/null
}

function populate_big_data() {
    echo "Populate DB with a lot of ramdom data"
    #redis-benchmark -h $docker_bridge_device_ip -t set,lpush -c $clients_num -n $requests_num -d $data_size -q -a redis --random-data 1
    redis-benchmark -h $docker_bridge_device_ip -t set -c $clients_num -n $requests_num -d $data_size -q -a redis -r 1000000000 --random-data 1
}

function restart_container() {
    echo "Restart replica container and apply tc qdisc"
    sudo docker restart redis_6380

}

function add_rate_limits() {
    sudo docker exec redis_6379 tc qdisc add dev eth0 root tbf rate 500mbit burst 5000000 limit 15000000 && \
    sudo docker exec redis_6380 tc qdisc add dev eth0 root tbf rate 500mbit burst 5000000 limit 15000000
}

function redeploy_container() {

    echo "Redeploy containers"
    sh /home/eadinno/redis-docker/setup_containers.sh
    sleep 2
}

function cleanup_test() {

    echo "Delete traffic control rules"
    sudo docker exec redis_6379 tc qdisc del dev eth0 root
    sudo docker exec redis_6380 tc qdisc del dev eth0 root
}

function test1_random_data() {
    echo -e "\tTest 1. Populate buffer with random data while bulk sync"
    flush_db
    populate_big_data
    wait_master_replica_online_sync
    restart_container
    add_rate_limits
    add_output_buffer_random_data
    wait_replica_bgsave
    cleanup_test
}

function test2_compressable_data() {
    echo -e "\tTest 2. Populate buffer with super compressable data while bulk sync"
    flush_db
    populate_big_data
    restart_container
    add_rate_limits
    add_output_buffer_compressable_data
    wait_replica_bgsave
    cleanup_test
}

function test3_real_data() {
    echo -e "\tTest 3. Populate buffer with real data while bulk sync"
    flush_db
    add_output_buffer_real_data
    populate_big_data
    restart_container
    add_rate_limits
    kill -10 $(pidof redis-benchmark) #SIGUSR1 to start setting data
    wait_replica_bgsave
    cleanup_test
}

function wait_master_replica_online_sync() {
    echo "Wait for offsets to be synced $(get_replica_offset):$(get_master_offset)"
    while [ "$(get_replica_offset)" != "$(get_master_offset)" ]; do
        sleep 1
    done
}

function wait_replica_bgsave() {
    echo "Bulk sync ongoing $(get_slave_state)"
    START="$(date +%s)"
    while [ "$(get_slave_state)" != "online" ]; do
        sleep 1
        #kill -10 $(pidof redis-benchmark)
    done
    DURATION=$[ $(date +%s) - ${START} ]
    echo "Bulk sync finished in ${DURATION} sec"

    echo "Max mem used: $(get_max_mem_used)"
}

main () {
    #test1_random_data
    #test2_compressable_data
    test3_real_data
    exit
    for i in "${compression_types[@]}"
    do
        echo -e "\tStart testing $i compression"
        set_compression_type $i

        test1_random_data
        test2_compressable_data
        test3_real_data
    done

}

main
