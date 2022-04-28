# Import Library

import matplotlib.pyplot as plt

def plot_two_bars(x_axis, y_axis, color_arr, label_arr, xlabel, ylabel, title):
    barWidth = 0.25
    # Set position of bar on X axis
    br1 = range(len(x_axis))
    br2 = [x + barWidth for x in br1]
    br3 = [x + barWidth for x in br2]

    fig = plt.figure()
    #ax = fig.add_axes([0,0,1,1])
    ax = plt.subplot()
    # plot bar chart

    #plt.xticks(range(len(x_axis)), x_axis)
    plt.bar(br1, y_axis[0], color=color_arr[0], width=barWidth, label=label_arr[0])
    plt.bar(br2, y_axis[1], color=color_arr[1], width=barWidth, label=label_arr[1])

    plt.xticks([r + barWidth for r in range(len(x_axis))], x_axis)

    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.set_title(title)

    # Display graph
    plt.legend()
    plt.show(block=False)
def plot_compression_cmp_bar(x_axis, y_axis, color_arr, label_arr, xlabel, ylabel, title):
    # Define Data

    # set width of bar
    barWidth = 0.25
    # Set position of bar on X axis
    br1 = range(len(x_axis))
    br2 = [x + barWidth for x in br1]
    br3 = [x + barWidth for x in br2]

    fig = plt.figure()
    #ax = fig.add_axes([0,0,1,1])
    ax = plt.subplot()
    # plot bar chart

    #plt.xticks(range(len(x_axis)), x_axis)
    plt.bar(br1, y_axis[0], color=color_arr[0], width=barWidth, label=label_arr[0])
    plt.bar(br2, y_axis[1], color=color_arr[1], width=barWidth, label=label_arr[1])
    plt.bar(br3, y_axis[2], color=color_arr[2], width=barWidth, label=label_arr[2])

    plt.xticks([r + barWidth for r in range(len(x_axis))], x_axis)

    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.set_title(title)

    # Display graph
    plt.legend()
    plt.show(block=False)

def plot_two_figs(x_axis, y_axis, color_arr, label_arr, xlabel, ylabel, title):
    fig = plt.figure()
    ax = plt.subplot()

    #x = list(range (len(x_axis)))
    #ax.set_xticklabels(x_axis[0])
    #plt.xticks(range(len(x_axis[0])),x_axis)
    plt.xticks(range(len(x_axis)), x_axis)
    plt.plot(y_axis[0], color=color_arr[0], label=label_arr[0])
    plt.plot(y_axis[1], color=color_arr[1], label=label_arr[1])

    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.set_title(title)

    plt.legend()
    plt.show(block=False)

def plot_three_figs(x_axis, y_axis, color_arr, label_arr, xlabel, ylabel, title):
    fig = plt.figure()
    ax = plt.subplot()

    #x = list(range (len(x_axis)))
    #ax.set_xticklabels(x_axis[0])
    #plt.xticks(range(len(x_axis[0])),x_axis)
    plt.xticks(range(len(x_axis)), x_axis)
    plt.plot(y_axis[0], color=color_arr[0], label=label_arr[0])
    plt.plot(y_axis[1], color=color_arr[1], label=label_arr[1])
    plt.plot(y_axis[2], color=color_arr[2], label=label_arr[2])

    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.set_title(title)

    plt.legend()
    plt.show(block=False)

def plot_subplots():
    fig,a = plt.subplots(2, 1)

    #compressable
    compression_type = [ "LZF", "LZ4"]
    memory_used_set  = [ 0.032273384, 0.017587464]
    memory_used_mset = [ 0.032101688, 0.017548312]
    memory_used_hset = [ 0.037323488, 0.019548640]
    a[0][0].plot(compression_type, memory_used_set, color='g', label='SET')
    a[0][0].plot(compression_type, memory_used_mset, color='r', label='MSET size 10')
    a[0][0].plot(compression_type, memory_used_hset, color='b', label='HSET')

    a[0][0].set_xlabel('Compression type')
    a[0][0].set_ylabel('Memory used (GB)')
    a[0][0].set_title('Memory impact of command types on super compressable data')
    #random
    memory_used_set =  [ 1.611757928, 0.806832488]
    memory_used_mset = [ 1.609912568, 0.805908728]
    memory_used_hset = [ 1.614484960, 0.808224224]
    a[1][0].plot(compression_type, memory_used_set, color='g', label='SET')
    a[1][0].plot(compression_type, memory_used_mset, color='r', label='MSET size 10')
    a[1][0].plot(compression_type, memory_used_hset, color='b', label='HSET')

    a[1][0].set_xlabel('Compression type')
    a[1][0].set_ylabel('Memory used (GB)')
    a[1][0].set_title('Memory impact of command types on super random data')

    plt.legend()
    plt.show(block=False)
#plot_compression_cmp_bar()
#plot_two_figs()

def compression_idx_by_type(compression_type):
    if compression_type == 'no':
        return 0
    if compression_type == 'lzf':
        return 1
    if compression_type == 'lz4':
        return 2

#plot_subplots()

def extract_used_memory(data, data_type, command_type):
    used_mem = []
    compression_type = []
    for i in data['test']:
        #print(i['compression-type'])
        compression_type.append(compression_idx_by_type(i['compression-type']))
        for j in i['items']:
            #print(j)
            if ('data-type', data_type) in j.items():
                if ('command-type', command_type) in j.items():
                    print(j['command-type'], data_type)
                    #label.append(j['command-type'])
                    used_mem.append(j['used-mem'])
            #label.append(j['command-type'])

    used_mem = list(map(float, used_mem))
    #rps, compression_type = zip(*sorted(zip(rps, compression_type)))
    compression_type, used_mem = zip(*sorted(zip(compression_type, used_mem)))
    return used_mem

def extract_latency(data, data_type, command_type, latency_param):
    lat_param = []
    compression_type = []
    for i in data['test']:
        #print(i['compression-type'])
        compression_type.append(compression_idx_by_type(i['compression-type']))
        for j in i['items']:
            #print(j)
            if ('data-type', data_type) in j.items():
                if ('command-type', command_type) in j.items():
                    #print(j['command-type'], data_type)
                    #label.append(j['command-type'])
                    latency = j['latency-report'].items()
                    for k, v in latency:
                        if (k == latency_param):
                            lat_param.append(v)
            #label.append(j['command-type'])

    lat_param = list(map(float, lat_param))
    #rps, compression_type = zip(*sorted(zip(rps, compression_type)))
    compression_type, lat_param = zip(*sorted(zip(compression_type, lat_param)))
    return lat_param

def main():
    import json
    f = open('results.out2')
    data = json.load(f)

    compression_type_label = ["No", "LZF", "LZ4"]
    res = []
    color = [ 'r', 'g', 'b']
    label = [ 'SET', 'MSET size 10', 'HSET']
    
    data_type = ["random", "compressable", "real"]
    command_type = ["set", "mset", "hset"]

    latency_param = 'rps'

    for cmd in command_type:      
        lat = extract_latency(data, "random", cmd, latency_param)
        res.append(lat)

    xlabel = 'Compression type'
    ylabel = 'Requests per second'
    title = 'Requests per Second on random data'
    plot_three_figs(compression_type_label, res, color, label, xlabel, ylabel, title)

    
    for cmd in command_type:      
        lat = extract_latency(data, "random", cmd, latency_param)
        res.append(lat)

    plot_three_figs(compression_type_label, res, color, label,
                    'Compression type',
                    'Requests per second',
                    'Requests per Second on compressable data')

    real_command_type= ["real_data_string_set", "real_data_string_mset"]
    #Extract real data
    res = []
    for cmd in real_command_type:      
        lat = extract_latency(data, "real", cmd, latency_param)
        if lat:
            res.append(lat)

    plot_two_figs(compression_type_label, res, color, label,
                    'Compression type',
                    'Requests per second',
                    'Requests per Second on real data')

    res = []
    for cmd in command_type:      
        used_mem = extract_used_memory(data, "random", cmd)
        res.append(used_mem)

    plot_compression_cmp_bar(compression_type_label, res, color, label, 
                    'Compression type',
                    'Memory Used (GB)',
                    'Memory impact of command types on random data')

    res = []
    for cmd in command_type:      
        used_mem = extract_used_memory(data, "compressable", cmd)
        if used_mem:
            res.append(used_mem)

    plot_compression_cmp_bar(compression_type_label, res, color, label, 
                    'Compression type',
                    'Memory Used (GB)',
                    'Memory impact of command types on compressable data')

    res = []
    for cmd in real_command_type:      
        used_mem = extract_used_memory(data, "real", cmd)
        res.append(used_mem)

    plot_two_bars(compression_type_label, res, color, label, 
                    'Compression type',
                    'Memory Used (GB)',
                    'Memory impact of command types on real data')

    plt.show()

if __name__ == "__main__":
    main()