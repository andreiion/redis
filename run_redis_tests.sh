#!/bin/bash

clients_num=4

redis_bridge_device_ip="172.18.0.2"
docker_bridge_device_ip="172.17.0.2"

requests_num="1600000"
data_size="1000"

tbf_bulksync_rate_limit="250mbit"

#real_data_test="real_data_string_mset"
log_date=`date +%Y:%m:%d:%H:%M`
log_file_name="log_$log_date.txt"

redis_benchmark_file="redis-benchmark.out"

declare -a compression_types=("no" "lzf" "lz4" "zstd")
#declare -a compression_types=("lzf")

#"mset" "sadd"
declare -a command_types=("set" "mset" "hset")
#declare -a command_types=("mset")

declare -a data_types=("real" "random" "compressible")
#declare -a data_types=("random")

logdata() {
    #Log data into a 'name:value' format
    local name=$1
    local value="$2"
    local log_depth=$(printf '\t%.0s' $(seq 1 $3))
    local sig_end=$4
    if [ -z "$2" ]
    then
        if [ -z "$3" ]
        then
            printf '%s\n' $1 >> $log_file_name
            return
        fi
        printf '%s%s\n' "$log_depth" $1 >> $log_file_name
        return
    fi

    if [[ "$value" == "[" || "$value" == "{" ]];
    then
        if [ -z "$3" ]
        then
            printf '\"%s\": %s\n' $name "$value" >> $log_file_name
            return
        fi
        printf '%s\"%s\": %s\n' "$log_depth" $name "$value" >> $log_file_name
        return
    fi

    if [ -z "$3" ]
    then
        if [[ "$sig_end" == "end" ]]; then
            printf '\"%s\": \"%s\"\n' $name "$value" >> $log_file_name
        return
        fi
        printf '\"%s\": \"%s\",\n' $name "$value" >> $log_file_name
        return
    fi
 
    if [[ "$sig_end" == "end" ]]; then
        printf '%s\"%s\": \"%s\"\n' "$log_depth" $name "$value" >> $log_file_name
        return
    fi
    printf '%s\"%s\": \"%s\",\n' "$log_depth" $name "$value" >> $log_file_name
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
    sudo docker exec --privileged $container_id /bin/bash -c '/usr/bin/perf record -o perf.data -g --pid $(pgrep -w redis-server -d, ) -F 999 -- sleep 240 ' &
}

function export_perf() {
    local container_id=$1
    local cmp_type=$2
    local data_type=$3
    local command_type=$4
    echo "kill perf for $container_id $cmp_type $data_type"
    sudo docker exec $container_id /bin/bash -c 'kill -SIGTERM $(pidof perf)'
    sudo docker exec $container_id /bin/bash -c 'while kill -0 $(pgrep perf) >/dev/null 2>&1; do sleep 1; done' #wait for proc to finish. can't do wait because perf started in another bash
    sudo docker exec $container_id /bin/bash -c 'perf script --input /perf.data > redis.perf.stacks'
    sudo docker cp $container_id:/redis.perf.stacks ~/${container_id}_perf.stacks

    ~/FlameGraph/stackcollapse-perf.pl ~/${container_id}_perf.stacks > ${container_id}_out.perf-folded
    sudo ~/FlameGraph/flamegraph.pl ${container_id}_out.perf-folded > ${container_id}_${cmp_type}_${data_type}_${command_type}.svg
}

function set_redis_compression_type() {
    local compression_type=$1
    echo "compression_type will be set to $compression_type"
    redis-cli -a redis -h $redis_bridge_device_ip -p 6379 CONFIG SET replica-output-buffer-compression $compression_type 2> /dev/null
    redis-cli -a redis -h $redis_bridge_device_ip -p 6379 CONFIG GET replica-output-buffer-compression 2> /dev/null
}

function set_redis_client_output_buffer_hard_limit() {
    local hard_limit=$1
    echo "set hard limit $hard_limit"
    redis-cli -a redis -h $redis_bridge_device_ip -p 6379 CONFIG SET client-output-buffer-limit "replica $hard_limit 0 0" 2> /dev/null
    redis-cli -a redis -h $redis_bridge_device_ip -p 6379 CONFIG GET client-output-buffer-limit 2> /dev/null
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
    
    if [[ -z "$max_mem_used" ]];
    then
        echo "0"
    fi
    
    echo "$max_mem_used"
}

function get_bgsave_close_time() {
    #redis-cli -a redis -h 172.18.0.2 info replication 2> /dev/null | grep bgsave_close_time | awk -F = '{print $2}' | tr -d '\n\r'
    local bgsave_close_time=$(redis-cli -a redis -h $redis_bridge_device_ip info replication 2> /dev/null | grep bgsave_close_time | awk -F = '{print $2}' | tr -d '\n\r')
    
    if [[ -z "$bgsave_close_time" ]];
    then
        echo 0
    fi

    #if [[ "$bgsave_close_time" -ne 0 ]]; then
    #    #echo "bgsave_close_time is $bgsave_close_time"
    #    logdata "buffer-filled-time" "$bgsave_close_time" 1 "end"
    #fi
    echo $bgsave_close_time
}

function wait_master_replica_online_sync() {
    #echo "-wait for offsets to be synced $(get_replica_offset):$(get_master_offset)"
    while [ "$(get_replica_offset)" != "$(get_master_offset)" ]; do
        sleep 1
    done

}

function wait_master_replica_online_sync_log() {
    #echo "-wait for offsets to be synced $(get_replica_offset):$(get_master_offset)"
    START_ONLINE="$(date +%s)"
    while [ "$(get_replica_offset)" != "$(get_master_offset)" ]; do
        sleep 0.1
    done
    DURATION_ONLINE=$[ $(date +%s) - ${START_ONLINE} ]
    echo "online offset sync finished in ${DURATION_ONLINE} sec"
    logdata "online-sync-duration" ${DURATION_ONLINE} 1
}

function wait_replica_bgsave() {
    #echo "-bulk sync ongoing $(get_slave_state)"
    START="$(date +%s)"
    while [ "$(get_slave_state)" != "online" ]; do
        sleep 1
    done
    DURATION=$[ $(date +%s) - ${START} ]
    echo "-bulk sync finished in ${DURATION} sec"
    logdata "bulk-sync-duration" ${DURATION} 1
    logdata "used-mem" $(get_max_mem_used) 1
}

function wait_buffer_filled() {
     while [ $(get_bgsave_close_time) -eq 0 ]; do
        
        #also check if redis-benchmark finished
        if [[ ! $(pgrep redis-benchmark) ]]; then
            echo "found max rate limit"
            logdata "used-mem" "$(get_max_mem_used)" 1
            logdata "buffer-filled-time" "0" 1 "end"
            return
        fi

        sleep 1
    done
    #echo "buffer-filled $(get_bgsave_close_time)"
    logdata "buffer-filled-time" "$(get_bgsave_close_time)" 1 "end"

    echo "kill redis-benchmark clients"
    pkill redis-benchmark
}

function extract_latency() {
    local compression_type=$1
    local data_type=$2
    local command_type=$3

    rps=$(grep "Summary" -A 4 $redis_benchmark_file | awk 'NR == 2' | awk -F: '{print $2}' | awk '{print $1}')
    latency_avg=$(grep "Summary" -A 4 $redis_benchmark_file | awk 'NR == 5' | awk '{print $1}')
    latency_min=$(grep "Summary" -A 4 $redis_benchmark_file | awk 'NR == 5' | awk '{print $2}')
    latency_p50=$(grep "Summary" -A 4 $redis_benchmark_file | awk 'NR == 5' | awk '{print $3}')
    latency_p95=$(grep "Summary" -A 4 $redis_benchmark_file | awk 'NR == 5' | awk '{print $4}')
    latency_p99=$(grep "Summary" -A 4 $redis_benchmark_file | awk 'NR == 5' | awk '{print $5}')
    latency_max=$(grep "Summary" -A 4 $redis_benchmark_file | awk 'NR == 5' | awk '{print $6}')
    exec_time=$(grep "requests completed in" $redis_benchmark_file | awk '{print $5}')

    logdata "latency-report" "{" 1
    logdata "exec_time_sec" $exec_time 2;
    logdata "rps" $rps 2;
    logdata "avg" $latency_avg 2;
    logdata "min" $latency_min 2;
    logdata "p50" $latency_p50 2;
    logdata "p95" $latency_p95 2;
    logdata "p99" $latency_p99 2;
    logdata "max" $latency_max 2 "end"
    logdata "}" "" 1 "end"
}

function add_output_buffer_random_data() {
    local test_type=$1

    if [ "$test_type" == "mset" ]; then
        redis-benchmark -h $docker_bridge_device_ip \
                        -t $test_type -c $clients_num \
                        -n $(expr $requests_num / "10") \
                        -d $data_size -a redis -r 1000000000 \
                        --random-data 1 --diff-value-random 1 &
    else
        #redis-benchmark -h 172.17.0.2 -p 6379 -t set -c 4 -n 1600000 -d 1000 -q -a redis -r 1000000000 --random-data 1 --diff-value-random 1
        redis-benchmark -h $docker_bridge_device_ip \
                        -t $test_type -c $clients_num \
                        -n $requests_num \
                        -d $data_size -a redis -r 1000000000 \
                        --random-data 1 --diff-value-random 1 &
    fi
}

function add_output_buffer_compressible_data() {
    local test_type=$1
    #echo "-add compressible data"
    if [ "$test_type" == "mset" ]; then
        redis-benchmark -h $docker_bridge_device_ip \
                        -t $test_type -c $clients_num \
                        -n $(expr $requests_num / "10") \
                        -d $data_size -a redis -r 1000000000 --random-data 0 &
    else
        #redis-benchmark -h 172.17.0.2 -p 6379 -t set -c 50 -n 160000 -d 10000 -q -a redis -r 1000000000 --random-data 1
        redis-benchmark -h $docker_bridge_device_ip \
                        -t $test_type -c $clients_num \
                        -n $requests_num \
                        -d $data_size -a redis -r 1000000000 --random-data 0 &
    fi
}

add_output_buffer_real_data() {
    local real_data_test="real_data_string_${1}"
    #echo "-add real data"
    #redis-benchmark -h 172.17.0.2 -p 6379 -a redis -t real_data_string_set
    redis-benchmark -h $docker_bridge_device_ip -a redis -t $real_data_test -c $clients_num &
}

function flush_db() {
    #echo "-flushing old DB data"
    redis-cli -a redis -h $redis_bridge_device_ip flushall 2> /dev/null
}

function populate_big_data() {
    echo "-populate DB with a lot of ramdom data"
    #redis-benchmark -h $docker_bridge_device_ip -t set,lpush -c $clients_num -n $requests_num -d $data_size -q -a redis --random-data 1
    redis-benchmark -h $docker_bridge_device_ip \
                    -t set -c $clients_num \
                    -n $requests_num \
                    -d "1300" \
                    -q -a redis -r 1000000000 --random-data 1 > /dev/null
}

function restart_container() {
    #echo "-restart replica container"
    sudo docker restart redis_6380
}

function add_rate_limits() {
    local rate_limit=$1
    local client_rate_limit=$2
    echo "set $rate_limit tbf limit"
    logdata "rate-limit" $rate_limit 1

    eth_dev_redis_6379=$(sudo docker exec redis_6379 /bin/bash -c 'ip a s  | grep 172.18.* | awk "{print \$NF}"')
    sudo docker exec redis_6379 tc qdisc add dev $eth_dev_redis_6379 root tbf rate $rate_limit burst 5000000 limit 15000000 & \
    sudo docker exec redis_6380 tc qdisc add dev eth0 root tbf rate $rate_limit burst 5000000 limit 15000000

    if [[ ! -z $client_rate_limit ]]; then
        logdata "client-rate-limit" $client_rate_limit 1
        sudo tc qdisc add dev docker0 root tbf rate $client_rate_limit burst 5000000 limit 15000000
    fi
}

function redeploy_containers() {
    #echo "-redeploy containers"
    bash /home/eadinno/redis-docker/setup_containers.sh > /dev/null
    sleep 1
}

function stop_start_containers() { 

    sudo docker exec redis_6380 /bin/bash -c 'rm -rf *.rdb'
    sudo docker stop redis_6380
    sudo docker stop redis_6379

    sudo docker start redis_6379
    sudo docker start redis_6380
}

function cleanup_test() {
    echo "cleanup test"

    eth_dev_redis_6379=$(sudo docker exec redis_6379 /bin/bash -c 'ip a s  | grep 172.18.* | awk "{print \$NF}"')
    sudo docker exec redis_6379 tc qdisc del dev $eth_dev_redis_6379 root
    sudo docker exec redis_6380 tc qdisc del dev eth0 root

    sudo tc qdisc del dev docker0 root
}

function test1_random_data() {
    local cmp_type=$1
    local command_type=$2
    local rate_limit=$3
    local client_output_buffer_limit=$5
    echo -e "Test 1. Populate buffer with random data while bulk sync"

    logdata "{" "" 1
    logdata "start-test-time" "$(date)" 1
    logdata "data-type" "random" 1

    stop_start_containers
    set_redis_compression_type $i
    add_output_buffer_random_data $command_type
    populate_big_data
    wait_master_replica_online_sync

    restart_container

    #if [[ "$cmp_type" == "lzf" ]]; then
    #    echo "Lower LZF rate limit as it's too slow"
    #    add_rate_limits "200mbit"
    #else
    #    add_rate_limits $rate_limit
    #fi
    
    add_rate_limits $rate_limit

    echo "sleep 10"
    sleep 10 # that's how much it takes to build the dataset
    start_perf "redis_6379"
    logdata "command-type" $command_type 1
    kill -10 $(pidof redis-benchmark) #SIGUSR1 to start setting data

    echo "call wait_replica_bgsave"
    wait_replica_bgsave
    
    #Test the time it took to decompress and send the data to the replica
    cleanup_test
    wait_master_replica_online_sync_log

    logdata "end-test-time" "$(date)" 1
    extract_latency
    export_perf "redis_6379" $cmp_type "random"  $command_type

    logdata "}," "" 1
}

function test2_compressible_data() {
    local cmp_type=$1
    local command_type=$2
    local rate_limit=$3
    local client_rate_limit=$4
    local client_output_buffer_limit=$5
    echo -e "Test 2. Populate buffer with super compressible data while bulk sync"

    logdata "{" "" 1
    logdata "start-test-time" "$(date)" 1
    logdata "data-type" "compressible" 1

    stop_start_containers
    set_redis_compression_type $i
    populate_big_data
    wait_master_replica_online_sync

    restart_container
    add_rate_limits $rate_limit $client_rate_limit

    if [ ! -z $client_output_buffer_limit ]; then
        echo "client_output_buffer_limit set to $client_output_buffer_limit"

        logdata "client-output-buffer-limit" $client_output_buffer_limit 1
        set_redis_client_output_buffer_hard_limit  $client_output_buffer_limit
    fi

    start_perf "redis_6379"
    logdata "command-type" $command_type 1
    add_output_buffer_compressible_data $command_type

    echo "call wait_replica_bgsave"
    wait_replica_bgsave

    #Test the time it took to decompress and send the data to the replica
    cleanup_test
    wait_master_replica_online_sync_log

    logdata "end-test-time" "$(date)" 1
    extract_latency
    export_perf "redis_6379" $cmp_type "compressible" $command_type

    logdata "}," "" 1
}

function test3_real_data() {
    local cmp_type=$1
    local data_type=$2
    local command_type=$3
    local rate_limit=$4
    local client_rate_limit=$5
    local client_output_buffer_limit=$6
    echo -e "Test 3. Populate buffer with real data while bulk sync"

    logdata "{" "" 1
    logdata "start-test-time" "$(date)" 1
    logdata "data-type" $data_type 1

    stop_start_containers
    set_redis_compression_type $i
    logdata "command-type" $command_type 1
    add_output_buffer_real_data $command_type
    populate_big_data
    wait_master_replica_online_sync

    sleep 15 # sleep 15 sec. This how much it takes for the SCAN and GET to complete
    start_perf "redis_6379"

    restart_container
    add_rate_limits $rate_limit $client_rate_limit

    kill -10 $(pidof redis-benchmark) #SIGUSR1 to start setting data
    
    echo "call wait_replica_bgsave"
    wait_replica_bgsave

    #Test the time it took to decompress and send the data to the replica
    cleanup_test
    wait_master_replica_online_sync_log

    logdata "end-test-time" "$(date)" 1
    extract_latency
    export_perf "redis_6379" $cmp_type $data_type $command_type

    logdata "}," "" 1
}

function test_all_data() {
    local cmp_type=$1; local data_type=$2
    local command_type=$3; local rate_limit=$4
    local client_rate_limit=$5; local client_output_buffer_limit=$6

    echo -e "Run test Populate buffer with ${data_type} data while bulk sync"
    logdata "{" "" 1
    logdata "data-type" $data_type 1
    logdata "command-type" $command_type 1

    setup_test_env "$cmp_type"

    if [[ "$data_type" == "random" ]]; then
        add_output_buffer_random_data $command_type
    elif [[  "$data_type" == "real" ]]; then
        add_output_buffer_real_data $command_type
    fi
    populate_big_data
    wait_master_replica_online_sync

    if [[ "$data_type" == "real" ]]; then
        sleep 15 # sleep 15 sec. This how much it takes for the SCAN and GET to complete
    fi

    restart_container
    add_rate_limits $rate_limit $client_rate_limit

    if [ ! -z $client_output_buffer_limit ]; then
        echo "client_output_buffer_limit set to $client_output_buffer_limit"

        logdata "client-output-buffer-limit" $client_output_buffer_limit 1
        set_redis_client_output_buffer_hard_limit  $client_output_buffer_limit
    fi

    if [[ "$data_type" == "random" ]]; then
        sleep 10 # that's how much it takes to build the dataset
    elif [[  "$data_type" == "compressible"  ]]; then
       add_output_buffer_compressible_data $command_type
    fi 
    #start_perf "redis_6379"
    kill -10 $(pidof redis-benchmark) #SIGUSR1 to start setting data (random and real data case only)

    if [ ! -z $client_output_buffer_limit ]; then
        echo "call wait_buffer_filled"
        wait_buffer_filled
    else
        echo "call wait_replica_bgsave"
        wait_replica_bgsave
        extract_latency
    fi
    #export_perf "redis_6379" $cmp_type "$data_type"

    logdata "}," "" 1
    cleanup_test
}

function run_buffer_limit_test() {
    echo "limit"
    local max_mem_buffer_bytes=2000000000 #2GB - data is not that big
    local mem_step=100000000 #100MB each iteration

    local max_rate_limit_bits_per_sec=1000000000 #1gbit
    local rate_step=200000000 #200mbit each iteration

    local mem_buffer_size=0
    while [[ $mem_buffer_size -lt $max_mem_buffer_bytes ]] ; do
        (( mem_buffer_size += $mem_step ))
        echo "size: $mem_buffer_size\n"

        local rate_limit=200000000 #100mbit starting speed
        while [[ $rate_limit -lt $max_rate_limit_bits_per_sec ]] ; do
        (( rate_limit += $rate_step ))
            echo "rate limit: $rate_limit; "
            run_tests $rate_limit $mem_buffer_size
        done
    done
    exit

    redeploy_containers
    wait_master_replica_online_sync
}

function run_no_limit_test() {
    redeploy_containers
    wait_master_replica_online_sync

    logdata "{" ""
    logdata "test" "["
    for i in "${compression_types[@]}"
    do
        #echo -e "-start testing $i compression"
        logdata "{" ""
        logdata "compression-type" $i
        logdata "items" "[" 1
        

        # execute different command types for the random and compressible data
        for j in "${command_types[@]}"
        do
            test1_random_data "$i" "$j" $tbf_bulksync_rate_limit | tee $redis_benchmark_file
        done

        for j in "${command_types[@]}"
        do
            test2_compressible_data "$i" "$j" $tbf_bulksync_rate_limit | tee $redis_benchmark_file
        done
        test3_real_data "$i" "real" "mset" $tbf_bulksync_rate_limit | tee $redis_benchmark_file
        test3_real_data "$i" "real" "set"  "200mbit" | tee $redis_benchmark_file #set is slow, reduce rate limit.

        printf "]\n" >> $log_file_name
        logdata "}" ""

    done
    logdata "]" ""
    logdata "}" "" #todo remove ',' if it's the last compression type
}

function setup_test_env() {
    local compression_type=$1
    #redeploy_containers
    #todo: do this instead of redeploy. we win a couple of seconds per test
    stop_start_containers
    wait_master_replica_online_sync
    echo "compression_type is $compression_type"
    set_redis_compression_type $compression_type
}

function run_tests() {
    redeploy_containers
    wait_master_replica_online_sync

    logdata "{" ""
    logdata "test" "["
    for i in "${compression_types[@]}"
    do
        #echo -e "-start testing $i compression"
        logdata "{" ""
        logdata "compression-type" $i
        logdata "items" "[" 1

        for data_type in "${data_types[@]}"
        do
            echo "$data_type"
            for cmd_type in "${command_types[@]}"
            do
                echo "$cmd_type"
                
                local max_mem_size_MB=1100 #1GB - data is not that big
                local min_mem_size_MB=100 #200 MB
                local mem_step_MB=50 #50MB each iteration
                local max_rate_limit_mbps=600 #600mbit
                local min_rate_limit_mbps=50 #50mbit
                local rate_step=25 #25mbit each iteration
                local mem_buffer_size=$max_mem_size_MB
                local client_rate_limit=$max_rate_limit_mbps
                while [[ $mem_buffer_size -gt $min_mem_size_MB ]] ; do
                    (( mem_buffer_size -= $mem_step_MB ))
                    echo "size: $mem_buffer_size"

                    while [[ $client_rate_limit -gt $min_rate_limit_mbps ]] ; do
                        if [ "$data_type" = "real" -a "$cmd_type" = "hset" ]; then
                            echo "Skip $cmd_type command for the $data_type data type"
                            break 3
                        fi

                        test_all_data "$i" "$data_type" "$cmd_type" $tbf_bulksync_rate_limit \
                                            "${client_rate_limit}mbit" \
                                            "${mem_buffer_size}mb" | tee $redis_benchmark_file

                        if [[ $(get_bgsave_close_time) -eq 0 ]]; then
                            break #found max rate limit. break from while
                        fi
                        (( client_rate_limit -= $rate_step ))
                    done
                done
            done
        done 
        
        logdata "]" "" 1
        logdata "}," ""

    done
    logdata "]" ""
    logdata "}" ""
}

main () {
    buffer_limit_flag=0
    while getopts 'l' name
    do
        case $name in
        l)
            buffer_limit_flag=1
            bval="$OPTARG"
            ;;
        ?)
            printf "Usage: %s: [-b value] args\n" $0
            exit 2
            ;;
        esac
    done

    START_TEST="$(date +%s)"
    if [ $buffer_limit_flag -eq 0 ]; then
        run_no_limit_test
    else
        run_tests
    fi
    DURATION_TEST=$[ $(date +%s) - ${START_TEST} ]
    echo "Tests finished in  ${DURATION_TEST} sec"
}

main "$@"
