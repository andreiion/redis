#!/bin/bash

clients_num=8

redis_bridge_device_ip="172.18.0.2"
docker_bridge_device_ip="172.17.0.2"

requests_num="160000"
data_size="10000"
tests="set"

tbf_rate_limit="500mbit"

#real_data_test="real_data_string_mset"
log_date=`date +%Y:%m:%d:%H:%M`
log_file_name="log_$log_date.txt"

declare -a compression_types=("lz4" "lzf" "no")

logdata() {
    #Log data into a 'name:value' format
    local name=$1
    local value=$2
    printf '%s:%s\n' $1 $2 >> $log_file_name
}

function start_profile_bpfcc()
{
    local container_id=$1
    sudo docker exec --privileged $container_id /bin/bash -c 'profile-bpfcc -F 999 -adf --pid $(pgrep -o redis-server) > out.profile-folded' &
}

function export_profile_bpfcc()
{
    local container_id=$1
    local cmp_type=$2
    local data_type=$3

    sudo docker exec $container_id /bin/bash -c 'kill -SIGTERM $(pgrep profile-bpfcc)'
    sudo docker exec $container_id /bin/bash -c 'while kill -0 $(pgrep profile-bpfcc) >/dev/null 2>&1; do sleep 1; done' #wait for proc to finish. can't do wait because perf started in another bash

    sudo docker cp $container_id:/out.profile-folded ~/${container_id}_profile.data

    sudo ~/FlameGraph/flamegraph.pl --colors=java ~/${container_id}_profile.data > ${container_id}_${cmp_type}_${data_type}_profile.svg
}

function start_perf() {
    local container_id=$1
    echo "start perf $container_id"
    sudo docker exec --privileged $container_id /bin/bash -c '/usr/bin/perf record -o perf.data -g --pid $(pgrep -w redis-server -d, ) -F 999 -- sleep 60 ' &
}

function export_perf() {
    local container_id=$1
    local cmp_type=$2
    local data_type=$3
    echo "kill $container_id $cmp_type $data_type"
    sudo docker exec $container_id /bin/bash -c 'kill -SIGTERM $(pidof perf)'
    sudo docker exec $container_id /bin/bash -c 'while kill -0 $(pgrep perf) >/dev/null 2>&1; do sleep 1; done' #wait for proc to finish. can't do wait because perf started in another bash

    sudo docker exec $container_id /bin/bash -c 'perf script --input /perf.data > redis.perf.stacks'
    sudo docker cp $container_id:/redis.perf.stacks ~/${container_id}_perf.stacks

    ~/FlameGraph/stackcollapse-perf.pl ~/${container_id}_perf.stacks > ${container_id}_out.perf-folded
    sudo ~/FlameGraph/flamegraph.pl ${container_id}_out.perf-folded > ${container_id}_${cmp_type}_${data_type}_perf.svg
}

function set_redis_compression_type() {
    local compression_type=$1
    redis-cli -a redis -h $redis_bridge_device_ip -p 6379 CONFIG SET replica-output-buffer-compression $compression_type 2> /dev/null

    redis-cli -a redis -h $redis_bridge_device_ip -p 6379 CONFIG GET replica-output-buffer-compression 2> /dev/null
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
    #echo "-add random data"
    #redis-benchmark -h -h 172.17.0.2 -p 6379 -t set -c 50 -n 160000 -d 10000 -q -a redis -r 1000000000 --random-data 1
    redis-benchmark -h $docker_bridge_device_ip -t $tests -c $clients_num -n $requests_num -d $data_size -q -a redis -r 1000000000 --random-data 1 &
}

function add_output_buffer_compressable_data() {
    #echo "-add compressable data"
    redis-benchmark -h $docker_bridge_device_ip -t $tests -c $clients_num -n $requests_num -d $data_size -q -a redis -r 1000000000 --random-data 0 &
}

add_output_buffer_real_data() {
    local real_data_test=$1
    #echo "-add real data"
    #redis-benchmark -h 172.17.0.2 -p 6379 -a redis -t real_data_string_mset
    redis-benchmark -h $docker_bridge_device_ip -a redis -q -t $real_data_test &
}

function flush_db() {
    #echo "-flushing old DB data"
    redis-cli -a redis -h $redis_bridge_device_ip flushall 2> /dev/null
}

function populate_big_data() {
    #echo "-populate DB with a lot of ramdom data"
    #redis-benchmark -h $docker_bridge_device_ip -t set,lpush -c $clients_num -n $requests_num -d $data_size -q -a redis --random-data 1
    redis-benchmark -h $docker_bridge_device_ip -t set -c $clients_num -n $requests_num -d $data_size -q -a redis -r 1000000000 --random-data 1
}

function restart_container() {
    #echo "-restart replica container"
    sudo docker restart redis_6380
}

function add_rate_limits() {
    local rate_limit=$1
    #echo "-set $rate_limit tbf limit"
    logdata "rate-limit" $tbf_rate_limit
    sudo docker exec redis_6379 tc qdisc add dev eth0 root tbf rate $rate_limit burst 5000000 limit 15000000 && \
    sudo docker exec redis_6380 tc qdisc add dev eth0 root tbf rate $rate_limit burst 5000000 limit 15000000
}

function redeploy_containers() {
    #echo "-redeploy containers"
    bash /home/eadinno/redis-docker/setup_containers.sh
    #sleep 10
}

function cleanup_test() {
    #echo "-delete traffic control rules"
    sudo docker exec redis_6379 tc qdisc del dev eth0 root
    sudo docker exec redis_6380 tc qdisc del dev eth0 root
}

function test1_random_data() {
    local cmp_type=$1
    echo -e "Test 1. Populate buffer with random data while bulk sync"
    logdata "data-type" "random"
    flush_db
    populate_big_data
    wait_master_replica_online_sync
    restart_container
    add_rate_limits $tbf_rate_limit
    #start_perf "redis_6380"
    start_perf "redis_6379"
    #start_profile_bpfcc "redis_6379"
    add_output_buffer_random_data
    wait_replica_bgsave
    export_perf "redis_6379" $cmp_type "random"
    #export_profile_bpfcc "redis_6379" $cmp_type "random"
    #export_perf "redis_6380" $cmp_type "random"
    cleanup_test
}

function test2_compressable_data() {
    local cmp_type=$1
    echo -e "Test 2. Populate buffer with super compressable data while bulk sync"
    logdata "data-type" "compressable"
    flush_db
    populate_big_data
    wait_master_replica_online_sync
    restart_container
    add_rate_limits $tbf_rate_limit
    start_perf "redis_6379"
    #start_profile_bpfcc "redis_6379"
    #start_perf "redis_6380"
    add_output_buffer_compressable_data
    wait_replica_bgsave
    export_perf "redis_6379" $cmp_type "compressable"
    #export_profile_bpfcc "redis_6379" $cmp_type "compressable"
    #export_perf "redis_6380" $cmp_type "compressable"
    cleanup_test
}

function test3_real_data() {
    local cmp_type=$1
    local real_data_test=$2
    local tbf_rate_limit=$3
    echo -e "Test 3. Populate buffer with real data while bulk sync"
    logdata "data-type" $real_data_test
    flush_db
    add_output_buffer_real_data $real_data_test
    populate_big_data
    wait_master_replica_online_sync
    restart_container
    add_rate_limits $tbf_rate_limit
    sleep 15 # sleep 15 sec. This how much it takes for the SCAN and GET to complete
    start_perf "redis_6379"
    #start_profile_bpfcc "redis_6379"
    #start_perf "redis_6380"
    kill -10 $(pidof redis-benchmark) #SIGUSR1 to start setting data
    wait_replica_bgsave
    export_perf "redis_6379" $cmp_type $real_data_test
    #export_profile_bpfcc "redis_6379" $cmp_type $real_data_test
    #export_perf "redis_6380" $cmp_type $real_data_test
    cleanup_test
}

function wait_master_replica_online_sync() {
    #echo "-wait for offsets to be synced $(get_replica_offset):$(get_master_offset)"
    while [ "$(get_replica_offset)" != "$(get_master_offset)" ]; do
        sleep 1
    done
}

function wait_replica_bgsave() {
    #echo "-bulk sync ongoing $(get_slave_state)"
    START="$(date +%s)"
    while [ "$(get_slave_state)" != "online" ]; do
        sleep 1
    done
    DURATION=$[ $(date +%s) - ${START} ]
    echo "-bulk sync finished in ${DURATION} sec"
    logdata "bulk-sync-duration" ${DURATION}
    logdata "used-mem" $(get_max_mem_used)
    #echo "used-mem: $(get_max_mem_used)"
}

main () {
    #test1_random_data
    #test2_compressable_data
    #test3_real_data
    #exit
    redeploy_containers
    wait_master_replica_online_sync

    #set_redis_compression_type "lz4"
    #test1_random_data "lz4"
    #sleep 100000
    #exit
    for i in "${compression_types[@]}"
    do
        #echo -e "-start testing $i compression"
        logdata "compression-type" $i
        set_redis_compression_type $i

        test1_random_data "$i"
        test2_compressable_data "$i"
        test3_real_data "$i" "real_data_string_mset" "500mbit"
        test3_real_data "$i" "real_data_string_set" "250mbit" #set is slow, reduce rate limit.

        printf "\n" >> $log_file_name
    done

}

main
