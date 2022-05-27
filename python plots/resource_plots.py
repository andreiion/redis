from datetime import datetime
from datetime import timedelta
import matplotlib.pyplot as plt
import pandas as pd
import plot_tools as pt

#df_cpu = pd.read_csv('cpu-usage-data-1sec.csv', header=0, delimiter=',')
df_cpu = pd.read_csv('CPU Usage (10 sec rate)-data-2022-05-20 17 46 08.csv', header=0, delimiter=',')

df_mem = pd.read_csv('memory-usage-data-1sec.csv', header=0, delimiter=',')
df_rxn = pd.read_csv('network-rx-data-1sec.csv', header=0, delimiter=',')
df_txn = pd.read_csv('network-tx-data-1sec.csv', header=0, delimiter=',')

df_cpu['Time'] = pd.to_datetime(df_cpu["Time"], errors='raise')
df_cpu['CPU Usage %'] = df_cpu['CPU Usage %'].str.strip('%').astype(float)

df_mem['Time'] = df_mem['Time'].astype('datetime64[ms]').dt.tz_localize('Etc/GMT+2').dt.tz_convert('GMT')
df_mem['Memory Usage GiB'] = df_mem['Memory Usage GiB'].div(1000000000)

df_rxn['Time'] = df_rxn['Time'].astype('datetime64[ms]').dt.tz_localize('Etc/GMT+2').dt.tz_convert('GMT')
df_rxn['Network RX (MBps)'] = df_rxn['Network RX (MBps)'].div(1000000)

df_txn['Time'] = df_txn['Time'].astype('datetime64[ms]').dt.tz_localize('Etc/GMT+2').dt.tz_convert('GMT')
df_txn['Network TX (MBps)'] = df_txn['Network TX (MBps)'].div(1000000)

#print(df_rxn)

#df_rxn['Time'] = pd.to_datetime(df_rxn["Time"], errors='raise')
#df_txn['Time'] = pd.to_datetime(df_txn["Time"], errors='raise')

df_cpu = df_cpu.set_index('Time')
df_mem = df_mem.set_index('Time')
df_rxn = df_rxn.set_index('Time')
df_txn = df_txn.set_index('Time')

def extract_test_start_end_times(data, data_type, command_type, ax, df):
    for i in data['test']:
        for j in i['items']:
            if ('data-type', data_type) in j.items() and ('command-type', command_type) in j.items():
                start_test_t = j['start-test-time']
                end_test_t = j['end-test-time']
                start_test_time_obj = datetime.strptime(start_test_t, '%a %B %d %H:%M:%S %Z %Y')
                end_test_time_obj = datetime.strptime(end_test_t, '%a %B %d %H:%M:%S %Z %Y')

                if df.columns[0] == 'Memory Usage GiB': #Advance time to skip noise in the data for memory usage
                    start_test_time_obj = start_test_time_obj + timedelta(seconds=3)
                    end_test_time_obj = end_test_time_obj - timedelta(seconds=3)

                if df.columns[0] == 'Network TX (MBps)': #Advance time to skip noise in the data for memory usage
                    end_test_time_obj = end_test_time_obj + timedelta(seconds=5)

                linestyle='solid'
                if command_type == 'mset':
                    linestyle = 'dashed'
                if command_type == 'hset':
                    linestyle = 'dotted'
                x = range(df[start_test_time_obj:end_test_time_obj].size)
                plot_label= i['compression-type'] + ' ' + command_type
                #plot_label= i['compression-type']
                plt.plot(x, df[start_test_time_obj:end_test_time_obj], label=plot_label, linestyle=linestyle)
                #plt.boxplot(df[start_test_time_obj:end_test_time_obj], label=plot_label)

                ax.set_xlabel('Time [s]')
                ax.set_ylabel(df.columns[0])
                ax.set_title(df.columns[0].strip('%') + ' for ' + data_type + ' data-set')
                plt.legend()

def plot_resources(data, data_type, command_type, df, fig_size):
    plt.rcParams["figure.figsize"] = [10.50, 7.50]
    #plt.rcParams["figure.figsize"] = fig_size
    plt.rcParams["figure.autolayout"] = True
    for data_t in data_type:
        fig, ax = plt.subplots()
        for cmd_t in command_type:
            #fig, ax = plt.subplots()
            extract_test_start_end_times(data, data_t, cmd_t, ax, df)
        
        #plt.rcParams["figure.figsize"] = [9.50, 7.50]
        #plt.rcParams["figure.autolayout"] = True
        #plt.savefig('resource_plots/' + df.columns[0] + ' ' + data_t)
        pt.save_fig(fig, 'resource_plots', df.columns[0].strip('%') + ' ' + data_t)
        #plt.show(block=False)