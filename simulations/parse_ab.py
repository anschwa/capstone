#!/usr/bin/env python3

# The job of this scirpt is to turn a lot of these...
#
# Connection Times (ms)
#               min  mean[+/-sd] median   max
# Connect:        0    0   0.0      0       0
# Processing:     0   98  99.9    104     606
# Waiting:        0   98  99.9    104     606
# Total:          0   99  99.9    104     606
#
#
# ...into a tsv formatted like this: (only the waiting time)
# min  mean  [+/-sd]  median  max
# 0    98    99.9     104     606
# 0    99    96.4     102     503
# 1    108   101.0    104     507
# 0    101   100.6    102     491
# etc.

import sys


def get_stats(ab):
    """
    (1) Search for the line containing 'Connection Times (ms)'
    (2) Save the statistics that appear on the following 5 lines
    """
    match = "Connection Times (ms)"

    for line in ab:
        i = ab.index(line)
        check = line.strip()

        if check == match:
            # skip the first two lines because we only want to data
            return ab[i+2:i+6]

    # this means we couldn't find any statistics
    raise Exception("ab statistics not found")


def get_data(stats):
    """format the statistics into a dictionary"""

    data = {}

    for s in stats:
        info = s.split()
        key = info[0][:-1]
        data[key] = "\t".join(info[1:])

    return data


def parse(ab, req, con, stat_opt="Total"):
    """Parse the output of Apache Bench and
    format the statistics into a tsv
    """

    # types of ab statistics available
    options = ["Connect", "Processing", "Waiting", "Total"]

    if stat_opt not in options:
        raise Exception("choice is not {}".format(options))

    stats = get_stats(ab)
    data = get_data(stats)

    print("{}\t{}\t{}".format(req, con, data[stat_opt]))

if __name__ == "__main__":
    req = sys.argv[1]
    con = sys.argv[2]
    parse(sys.stdin.readlines(), req, con, "Waiting")
