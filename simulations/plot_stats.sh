#!/usr/bin/env bash
# turn all the load balancing ab stats into box plot

SER=$1
REQ=$2
CON=$3
DIR=$4

if [ $# -lt 4 ]; then
    echo "usage: ./make_box_plot.sh <servers> <requests> <concurrent> <plot directory>"
    exit 1
fi

plt="$DIR/stats-$(date +%s).png"

################################################################################

echo "plotting all ab stat data files..."

gnuplot <<EOF
    # make a combined benchmark plot for all algorithms

    set terminal png size 700, 500 noenhanced
    set size 1, 1

    set title "Performance of Load Balancing Algorithms on Nginx\n\
Looking at min, mean, and max request latencies with\n\
$SER servers, $REQ requests, and $CON concurrent connections"

    set xlabel "Algorithm"
    set ylabel "Response Time for Request Completion (ms)"

    set datafile separator '\t'
    set output "$plt"

    set boxwidth 0.2
    set xtics ("control\n(1 server)" 1, "round_robin" 2, "least_conn" 3, "random" 4, "two_choices" 5)
    set xrange [0:6]
    
    set key top left

    # xlabel:median:min:median:max
    # ab doesn't provide quartiles, but we can plot min, mean, max this way
    plot "data/stats/control.tsv" every ::1 using (1):4:3:7:4 notitle with candlesticks, \
    "data/stats/round_robin.tsv" every ::1 using (2):4:3:7:4 notitle with candlesticks, \
    "data/stats/least_conn.tsv" every ::1 using (3):4:3:7:4 notitle with candlesticks, \
    "data/stats/random.tsv" every ::1 using (4):4:3:7:4 notitle with candlesticks, \
    "data/stats/two_choices.tsv" every ::1 using (5):4:3:7:4 notitle with candlesticks

    unset output
EOF

echo "saved $plt"
