from pathlib import Path
import matplotlib.pyplot as plt

def save_fig(fig, out_dir, name, extension='pdf'):
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    fig.savefig("{}/{}.{}".format(out_dir, name, extension),
                bbox_inches='tight', dpi=300)

def get_figsize(width, fraction=1):
    """ Set aesthetic figure dimensions to avoid scaling in latex.

    Parameters
    ----------
    width: float
            Width in pts
    fraction: float
            Fraction of the width which you wish the figure to occupy

    Returns
    -------
    fig_dim: tuple
            Dimensions of figure in inches
    """
    # Width of figure
    fig_width_pt = width * fraction

    # Convert from pt to inches
    inches_per_pt = 1 / 72.27

    # Golden ratio to set aesthetic figure height
    golden_ratio = (5**.5 - 1) / 2

    # Figure width in inches
    fig_width_in = fig_width_pt * inches_per_pt
    # Figure height in inches
    fig_height_in = fig_width_in * golden_ratio

    fig_dim = (fig_width_in, fig_height_in)

    return fig_dim

def plot_four_plot_dots(x_axis, y_axis, color_arr, label_arr, xlabel, ylabel, title):
    fig = plt.figure()
    ax = plt.subplot()

    plt.plot(x_axis[0], y_axis[0], 'o', color=color_arr[0], label=label_arr[0])
    plt.plot(x_axis[1], y_axis[1], 'b^', color=color_arr[1], label=label_arr[1])
    plt.plot(x_axis[2], y_axis[2], 'b*', color=color_arr[2], label=label_arr[2])
    plt.plot(x_axis[3], y_axis[3], 'P', color=color_arr[3], label=label_arr[3])

    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.set_title(title)

    plt.legend()
    save_fig(fig, 'plots/', title)
    #plt.show(block=False)

def plot_four_plot_dots_subplot(a, x_axis, y_axis, color_arr, label_arr, data_type):

    #a.plot(x_axis[0], y_axis[0], 'o', color=color_arr[0], label=label_arr[0])
    #a.plot(x_axis[1], y_axis[1], 'b^', color=color_arr[1], label=label_arr[1])
    #a.plot(x_axis[2], y_axis[2], 'b*', color=color_arr[2], label=label_arr[2])
    #a.plot(x_axis[3], y_axis[3], 'P', color=color_arr[3], label=label_arr[3])

    a.plot(x_axis[0], y_axis[0], color=color_arr[0], label=label_arr[0])
    a.plot(x_axis[1], y_axis[1], color=color_arr[1], label=label_arr[1])
    a.plot(x_axis[2], y_axis[2], color=color_arr[2], label=label_arr[2])
    a.plot(x_axis[3], y_axis[3], color=color_arr[3], label=label_arr[3])

    #a.set_xticks([0])
    if data_type == 'random':
         a.set_xlim(left=500)
         a.set_ylim(top=200, bottom=50) 
    else:
        a.axhline(y=600, xmin=0, xmax=3, c="black", linewidth=2, zorder=10, label='lower bound')
        a.set_xlim(left=200) 
        #a.set_xlim(left=100)
        a.set_ylim(top=650, bottom=50)
    #a.yline(3,'-','Threshold');
    #a.set_xlabel(xlabel)
    #a.set_ylabel(ylabel)
    #a.legend()

def plot_two_bars(a, x_axis, y_axis, color_arr, label_arr, xlabel='', ylabel='', title=''):
    barWidth = 0.25
    # Set position of bar on X axis
    br1 = range(len(x_axis))
    br2 = [x + barWidth for x in br1]
    br3 = [x + barWidth for x in br2]

    a.bar(br1, y_axis[0], color=color_arr[0], width=barWidth, label=label_arr[0])
    a.bar(br2, y_axis[1], color=color_arr[1], width=barWidth, label=label_arr[1])

    a.set_xticks([r + barWidth for r in range(len(x_axis))], x_axis)
    a.set_ylabel(ylabel)
    a.legend()


def plot_three_bars(a, x_axis, y_axis, color_arr, label_arr, xlabel='', ylabel='', title=''):
    # set width of bar
    barWidth = 0.25
    # Set position of bar on X axis
    br1 = range(len(x_axis))
    br2 = [x + barWidth for x in br1]
    br3 = [x + barWidth for x in br2]

    a.bar(br1, y_axis[0], color=color_arr[0], width=barWidth, label=label_arr[0])
    a.bar(br2, y_axis[1], color=color_arr[1], width=barWidth, label=label_arr[1])
    a.bar(br3, y_axis[2], color=color_arr[2], width=barWidth, label=label_arr[2])

    a.set_xticks([r + barWidth for r in range(len(x_axis))], x_axis)
    a.set_ylabel(ylabel)
    a.legend()
    
def plot_two_figs(x_axis, y_axis, color_arr, label_arr, xlabel, ylabel, title):
    fig = plt.figure()
    ax = plt.subplot()

    plt.xticks(range(len(x_axis)), x_axis)
    plt.plot(y_axis[0], color=color_arr[0], label=label_arr[0])
    plt.plot(y_axis[1], color=color_arr[1], label=label_arr[1])

    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.set_title(title)

    plt.legend()
    save_fig(fig, 'plots/', title)
    plt.show(block=False)

def plot_three_figs(x_axis, y_axis, color_arr, label_arr, xlabel, ylabel, title):
    fig = plt.figure()
    ax = plt.subplot()

    plt.xticks(range(len(x_axis)), x_axis)
    plt.plot(y_axis[0], color=color_arr[0], label=label_arr[0])
    plt.plot(y_axis[1], color=color_arr[1], label=label_arr[1])
    plt.plot(y_axis[2], color=color_arr[2], label=label_arr[2])

    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.set_title(title)

    plt.legend()
    save_fig(fig, 'plots/', title)
    plt.show(block=False)

def compression_idx_by_type(compression_type):
    if compression_type == 'no':
        return 0
    if compression_type == 'lzf':
        return 1
    if compression_type == 'lz4':
        return 2
    if compression_type == 'zstd':
        return 3
