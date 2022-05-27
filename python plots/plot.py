# Import Library

import matplotlib.pyplot as plt
import resource_plots as rp
import json
import plot_tools as pt
import os,glob

def extract_used_memory(data, data_type, command_type):
    if data_type == 'real' and command_type == 'hset':
        return 0

    used_mem = []
    compression_type = []

    for i in data['test']:
        compression_type.append(pt.compression_idx_by_type(i['compression-type']))
        for j in i['items']:
            if ('data-type', data_type) in j.items():
                if ('command-type', command_type) in j.items():
                    used_mem.append(j['used-mem'])

    used_mem = list(map(float, used_mem))
    #rps, compression_type = zip(*sorted(zip(rps, compression_type)))
    compression_type, used_mem = zip(*sorted(zip(compression_type, used_mem)))

    used_mem_gb = [number / 1000000000 for number in used_mem]

    #return used_mem
    return used_mem_gb

def extract_used_online_sync_duration(data, tests_str, data_type, command_type):
    if data_type == 'real' and command_type == 'hset':
        return 0

    online_sync_duration = []
    compression_type = []
    for i in data[tests_str]:
        compression_type.append(pt.compression_idx_by_type(i['compression-type']))
        for j in i['items']:
            if ('data-type', data_type) in j.items():
                if ('command-type', command_type) in j.items():
                    online_sync_duration.append(j['online-sync-duration-msec'])

    online_sync_duration = list(map(float, online_sync_duration))
    online_sync_duration = list(map(lambda x: x/1000, online_sync_duration))
    compression_type, online_sync_duration = zip(*sorted(zip(compression_type, online_sync_duration)))
    return online_sync_duration


def extract_latency(data, test_str, data_type, command_type, latency_param):
    if data_type == 'real' and command_type == 'hset':
        return []

    lat_param = []
    compression_type = []
    for i in data[test_str]:
        compression_type.append(pt.compression_idx_by_type(i['compression-type']))
        for j in i['items']:
            if ('data-type', data_type) in j.items():
                if ('command-type', command_type) in j.items():
                    latency = j['latency-report'].items()
                    for k, v in latency:
                        if (k == latency_param):
                            lat_param.append(v)
    if not lat_param:
        return []
    lat_param = list(map(float, lat_param))
    #rps, compression_type = zip(*sorted(zip(rps, compression_type)))
    compression_type, lat_param = zip(*sorted(zip(compression_type, lat_param)))
    return lat_param



#limits could be client-rate-limit or client-output-buffer-limit
#todo compression_type is passed as argument and also emptied inside the function
def extract_limits(data, compression_type, data_type, command_type):
    
    rate_arr = []
    mem_arr = []
    for i in data['test']:
        if i['compression-type'] == compression_type:
            for j in i['items']:
                if ('data-type', data_type) in j.items() and ('command-type', command_type) in j.items() :
                    if (j['buffer-filled-time'] == "0"):
                        rate_val = j['client-rate-limit']
                        mem_val = j['client-output-buffer-limit']
                        rate_arr.append(int(rate_val))
                        mem_arr.append(int(mem_val))
    return rate_arr, mem_arr

def extract_compression_ratio(data, compression_type, data_type, command_type):
    no_compression_memory = 0
    compression_memory = 0
    for i in data['test']:
        if i['compression-type'] == "no":
            for j in i['items']:
                if ('data-type', data_type) in j.items() and ('command-type', command_type) in j.items():
                    no_compression_memory = float(j['used-mem'])
        if i['compression-type'] == compression_type:
            for j in i['items']:
                if ('data-type', data_type) in j.items() and ('command-type', command_type) in j.items():
                    compression_memory = float(j['used-mem'])

    if no_compression_memory == 0 or compression_memory == 0:
        return 0 #something went wrong
    
    ratio = no_compression_memory / compression_memory

    return ratio

def rps_method(data, compression_type, data_type, command_type, colors, fig_size):
    label = command_type
    plt.rcParams["figure.figsize"] = fig_size
    plt.rcParams["figure.autolayout"] = True

    res_random = []
    res_compressible = []
    res_real = []
    latency_param = 'rps'
    test_str = 'test'
    for cmd in command_type:
        lat = extract_latency(data, test_str, "random", cmd, latency_param)
        if lat:
            res_random.append(lat)

        lat = extract_latency(data, test_str, "compressible", cmd, latency_param)
        if lat:
            res_compressible.append(lat)

        lat = extract_latency(data, test_str, "real", cmd, latency_param)
        if lat:
            res_real.append(lat)

    labels = ['a)', 'b)', 'c)']
    fig,a =  plt.subplots(3, sharex=True, sharey=True)

    for i in range(3):
        a[i].set_title(labels[i], fontfamily='serif', loc='left', fontsize='medium')

    pt.plot_three_bars(a[0], compression_type, res_random, colors, label)
    pt.plot_three_bars(a[1], compression_type, res_compressible, colors, label)
    pt.plot_two_bars(a[2], compression_type, res_real, colors, label)

    title='RPS on random, compressible, and real data-set'
    ylabel='Requests Per Second'
    fig.suptitle(title)
    fig.supxlabel('Compression type')
    fig.supylabel(ylabel)

    pt.save_fig(fig, 'plots/', title)

def memory_impact_method(data, compression_type, data_type, command_type, colors, fig_size):
    label = command_type
    plt.rcParams["figure.figsize"] = fig_size
    plt.rcParams["figure.autolayout"] = True

    res_random = []
    res_compressible = []
    res_real = []
    for cmd in command_type:
        used_mem = extract_used_memory(data, "random", cmd)
        if used_mem:
            res_random.append(used_mem)

        used_mem = extract_used_memory(data, "compressible", cmd)
        if used_mem:
            res_compressible.append(used_mem)

        used_mem = extract_used_memory(data, "real", cmd)
        res_real.append(used_mem)

    labels = ['a)', 'b)', 'c)']
    fig,a =  plt.subplots(3, sharex=True, sharey=True)

    for i in range(3):
        a[i].set_title(labels[i], fontfamily='serif', loc='left', fontsize='medium')
    
    pt.plot_three_bars(a[0], compression_type, res_random, colors, label)
    pt.plot_three_bars(a[1], compression_type, res_compressible, colors, label)
    pt.plot_two_bars(a[2], compression_type, res_real, colors, label)

    title='Memory Impact on random, compressible, and real data-set'
    ylabel='Used Buffer Memory [GB]'
    fig.suptitle(title)
    fig.supxlabel('Compression type')
    fig.supylabel(ylabel)

    pt.save_fig(fig, 'plots/', title)
    

def sync_duration_method(data, compression_type, data_type, command_type, colors, fig_size):
    label = command_type
    plt.rcParams["figure.figsize"] = fig_size
    plt.rcParams["figure.autolayout"] = True

    res_random = []
    res_compressible = []
    res_real = []
    test_str = 'test'
    for cmd in command_type:
        sync_duration = extract_used_online_sync_duration(data, test_str, "random", cmd)
        if sync_duration:
            res_random.append(sync_duration)

        sync_duration = extract_used_online_sync_duration(data, test_str, "compressible", cmd)
        if sync_duration:
            res_compressible.append(sync_duration)

        sync_duration = extract_used_online_sync_duration(data, test_str, "real", cmd)
        if sync_duration:
            res_real.append(sync_duration)

    labels = ['a)', 'b)', 'c)']
    fig,a =  plt.subplots(3, sharex=True, sharey=True)

    for i in range(3):
        a[i].set_title(labels[i], fontfamily='serif', loc='left', fontsize='medium')
    
    pt.plot_three_bars(a[0], compression_type, res_random, colors, label)
    pt.plot_three_bars(a[1], compression_type, res_compressible, colors, label)
    pt.plot_two_bars(a[2], compression_type, res_real, colors, label)

    title='Sync duration on random, compressible, and real data-set'
    ylabel='Duration [sec]'
    fig.suptitle(title)
    fig.supxlabel('Compression type')
    fig.supylabel(ylabel)

    pt.save_fig(fig, 'plots/', title)

def sync_duration_avg_plot(data, compression_type, data_type, command_type, colors, fig_size):
    label = command_type
    plt.rcParams["figure.figsize"] = fig_size
    plt.rcParams["figure.autolayout"] = True

    res_random = []
    res_compressible = []
    res_real = []
    for cmd in command_type:
        sync_duration_random_sum = [0, 0, 0, 0]
        sync_duration_compressible_sum = [0, 0, 0, 0]
        sync_duration_real_sum = [0, 0, 0, 0]
        for i in data:
            #test_str = "test" + str(i.index())
            test_str = 'test'
            sync_duration = extract_used_online_sync_duration(i, test_str, "random", cmd)
            if sync_duration:
                zip_list = zip (sync_duration, sync_duration_random_sum)
                sync_duration_random_sum =  [x + y for (x, y) in zip_list]
            
            sync_duration = extract_used_online_sync_duration(i, test_str, "compressible", cmd)
            if sync_duration:
                zip_list = zip (sync_duration, sync_duration_compressible_sum)
                sync_duration_compressible_sum =  [x + y for (x, y) in zip_list]

            sync_duration = extract_used_online_sync_duration(i, test_str, "real", cmd)
            if sync_duration:
                zip_list = zip (sync_duration, sync_duration_real_sum)
                sync_duration_real_sum =  [x + y for (x, y) in zip_list]


        res_random.append(sync_duration_random_sum)
        res_compressible.append(sync_duration_compressible_sum)
        res_real.append(sync_duration_real_sum)
        

    res_random = [list(map(lambda y: y/len(data), x)) for x in res_random]
    res_compressible = [list(map(lambda y: y/len(data), x)) for x in res_compressible]
    res_real = [list(map(lambda y: y/len(data), x)) for x in res_real]

    print("Sync duration")
    print (res_random)
    print (res_compressible)
    print (res_real)

    labels = ['a)', 'b)', 'c)']
    fig,a =  plt.subplots(3, sharex=True, sharey=True)

    for i in range(3):
        a[i].set_title(labels[i], fontfamily='serif', loc='left', fontsize='medium')
    
    pt.plot_three_bars(a[0], compression_type, res_random, colors, label)
    pt.plot_three_bars(a[1], compression_type, res_compressible, colors, label)
    pt.plot_two_bars(a[2], compression_type, res_real, colors, label)

    title='Sync duration on random, compressible, and real data-set (avg over ' + str(len(data)) + ' executions)'
    ylabel='Duration [sec]'
    fig.suptitle(title)
    fig.supxlabel('Compression type')
    fig.supylabel(ylabel)

    pt.save_fig(fig, 'plots/', title)

def rps_avg_plot(data, compression_type, data_type, command_type, colors, fig_size):
    label = command_type
    plt.rcParams["figure.figsize"] = fig_size
    plt.rcParams["figure.autolayout"] = True

    latency_param = 'rps'
    res_random = []
    res_compressible = []
    res_real = []
    for cmd in command_type:
        lat_random_sum = [0, 0, 0, 0]
        lat_compressible_sum = [0, 0, 0, 0]
        lat_real_sum = [0, 0, 0, 0]
        for i in data:
            #test_str = "test" + str(i.index())
            test_str = 'test'
            lat = extract_latency(i, test_str, "random", cmd, latency_param)
            if lat:
                zip_list = zip (lat, lat_random_sum)
                lat_random_sum =  [x + y for (x, y) in zip_list]
            
            lat = extract_latency(i, test_str, "compressible", cmd, latency_param)
            if lat:
                zip_list = zip (lat, lat_compressible_sum)
                lat_compressible_sum =  [x + y for (x, y) in zip_list]

            lat = extract_latency(i, test_str, "real", cmd, latency_param)
            if lat:
                zip_list = zip (lat, lat_real_sum)
                lat_real_sum =  [x + y for (x, y) in zip_list]

        res_random.append(lat_random_sum)
        res_compressible.append(lat_compressible_sum)
        res_real.append(lat_real_sum)

    res_random = [list(map(lambda y: y/len(data), x)) for x in res_random]
    res_compressible = [list(map(lambda y: y/len(data), x)) for x in res_compressible]
    res_real = [list(map(lambda y: y/len(data), x)) for x in res_real]


    print("RPS ")
    print (res_random)
    print (res_compressible)
    print (res_real)


    labels = ['a)', 'b)', 'c)']
    fig,a =  plt.subplots(3, sharex=True, sharey=True)

    for i in range(3):
        a[i].set_title(labels[i], fontfamily='serif', loc='left', fontsize='medium')

    pt.plot_three_bars(a[0], compression_type, res_random, colors, label)
    pt.plot_three_bars(a[1], compression_type, res_compressible, colors, label)
    pt.plot_two_bars(a[2], compression_type, res_real, colors, label)

    title='RPS on random, compressible, and real data-set (avg over ' + str(len(data)) + ' executions)'
    ylabel='Requests Per Second'
    fig.suptitle(title)
    fig.supxlabel('Compression type')
    fig.supylabel(ylabel)

    pt.save_fig(fig, 'plots/', title)

def plot_df(df, title, xlabel_plot, ylabel_plot, color_plot, start_time="", end_time=""):
    plt.rcParams["figure.figsize"] = [7.50, 3.50]
    plt.rcParams["figure.autolayout"] = True

    if not start_time or not end_time:
        df.plot(title = title, xlabel=xlabel_plot, ylabel=ylabel_plot, color=color_plot)
        return
    
    df[start_time:end_time].plot(title = title, xlabel=xlabel_plot, ylabel=ylabel_plot, color=color_plot)

def buffer_limit_testing(data, compression_type, data_type, command_type, colors, fig_size):
    rate_arr=[]
    mem_arr=[]

    #plt.rcParams["figure.figsize"] = fig_size
    plt.rcParams["figure.autolayout"] = True
    plt.rcParams["figure.figsize"] = fig_size
    for cmd_t in command_type:

        labels = ['a)', 'b)', 'c)']
        #fig,a =  plt.subplots(3, sharex=True, sharey=True)
        fig,a =  plt.subplots(3, sharex=False, sharey=False)
        for i in range(3):
            a[i].set_title(labels[i], fontfamily='serif', loc='left', fontsize='medium')

        for data_t in data_type:
            if data_t == 'real' and cmd_t == 'hset':
                continue
            rate_arr = []
            mem_arr = []

            for cmp_t in compression_type:
                rate, mem = extract_limits(data, cmp_t, data_t, cmd_t)
                if rate and mem:
                    rate_arr.append(rate)
                    mem_arr.append(mem)
            pt.plot_four_plot_dots_subplot(a[data_type.index(data_t)], mem_arr, rate_arr, colors, compression_type, data_t)
            if data_type.index(data_t) == 1:
                a[data_type.index(data_t)].legend()
        
        title='Thresholds for random, compressible, and real data-set (' + cmd_t+ ')'
        ylabel='Max Transfer rate (Mbps)'
        fig.suptitle(title)
        fig.supxlabel('Output Buffer Size (MB)')
        fig.supylabel(ylabel)
        #fig.legend(labels=compression_type, loc="center right",)

        pt.save_fig(fig, 'plots/', title)

def buffer_no_limit_testing_plot(data, compression_type, data_type, command_type, colors, fig_size):
    for cmp_t in compression_type:
        for data_t in data_type:
            for cmd_t in command_type:
                ratio = extract_compression_ratio(data, cmp_t, data_t, cmd_t)
                print(cmp_t, cmd_t, data_t, "ratio ", ratio)

    memory_impact_method(data, compression_type, data_type, command_type, colors, fig_size)
    rps_method(data, compression_type, data_type, command_type, colors, fig_size)
    sync_duration_method(data, compression_type, data_type, command_type, colors, fig_size)


def no_limit_avg_plot(data, compression_type, data_type, command_type, colors, fig_size):
    
    sync_duration_avg_plot(data, compression_type, data_type, command_type, colors, fig_size)
    rps_avg_plot(data, compression_type, data_type, command_type, colors, fig_size)

def main():
    compression_type = ['no', 'lzf', 'lz4', 'zstd']
    data_type = ['random', 'compressible', 'real']
    command_type = ['set', 'mset', 'hset']
    colors = [ '#9b59b6', '#e74c3c', '#3498db', '#05c46b']

    f = open('no_limit.out')
    no_limits_data = json.load(f)

    f = open('limit_final.out')
    limits_data = json.load(f)
    
    text_width = 426.79135  # pt
    good_width, good_height = pt.get_figsize(text_width)
    good_height *= 2.2
    fig_size_limit = (good_width, good_height)
    fig_size_no_limit = (good_width, good_height)
    fig_size_no_limit = [7, 8]
    fig_size_limit = [6, 7]
    
    #buffer_no_limit_testing_plot(no_limits_data, compression_type, data_type, command_type, colors, fig_size_no_limit)
    buffer_limit_testing(limits_data, compression_type, data_type, command_type, colors, fig_size_limit )

    '''folder_path = '/Users/eadinno/Library/CloudStorage/OneDrive-Ericsson/master-thesis/avg_data/'
    data_array = []
    for filename in glob.glob(os.path.join(folder_path, '*')):
        with open(filename, 'r') as f:
            #data_array.append(json.load(f))
            print (filename)
    '''

    f = open('no_limit_20_avg.out')
    avg_data = json.load(f)
    #no_limit_avg_plot(avg_data, compression_type, data_type, command_type, colors, fig_size_no_limit )

    #rp.plot_resources(no_limits_data, data_type, command_type, rp.df_cpu, fig_size_limit)
    #rp.plot_resources(no_limits_data, data_type, command_type, rp.df_mem)
    #rp.plot_resources(no_limits_data, data_type, command_type, rp.df_rxn)
    #rp.plot_resources(no_limits_data, data_type, command_type, rp.df_txn)
    
    #plot_df(df_cpu, 'CPU Usage on Master server', 'Time', 'CPU usage %', '#3c40c6')
    #plot_df(df_mem, 'Memory Usage on Master server', 'Time', 'Memory Usage (GB)', '#3c40c6')
    #plot_df(df_rxn, 'Network RX on Master server', 'Time', 'bps', '#3c40c6')
    #plot_df(df_txn, 'Network TX on Master server', 'Time', 'bps', '#3c40c6')
             
    plt.show()

if __name__ == "__main__":
    main()