#!/usr/bin/env bash
# turn all the load balancing data files into a single plot

SER="$1"
REQ="$2"
CON="$3"
DIR="$4"

if [ $# -lt 4 ]; then
    echo "usage: ./make_plot.sh <servers> <requests> <concurrency> <plot directory>"
    exit 1
fi

nginx_plt="$DIR/nginx-$(date +%s).png"

################################################################################

echo "plotting all nginx data files..."

# turn gnuplot x-axis to percentage
xval="((\$0/"$REQ")*100)"

gnuplot <<EOF
    # make a combined benchmark plot for all algorithms

    set terminal png size 500, 500 noenhanced
    set size 1, 1

    set grid y

    set title "Comparing Load Balancing Algorithms on Nginx\n$SER Server(s) and $CON Concurrent Connections"
    set xlabel "Percentage of Requests Served ($REQ total)"
    set ylabel "Response Time for Completion (ms)"

    set datafile separator '\t'
    set output "$nginx_plt"

    plot "ab_data/data/control/control.tsv" every ::2 using $xval:5 title "control" with lines, \
    "ab_data/data/round_robin/round_robin.tsv" every ::2 using $xval:5 title "round_robin" with lines, \
    "ab_data/data/least_conn/least_conn.tsv" every ::2 using $xval:5 title "least_conn" with lines, \
    "ab_data/data/random/random.tsv" every ::2 using $xval:5 title "random" with lines, \
    "ab_data/data/two_choices/two_choices.tsv" every ::2 using $xval:5 title "two_choices" with lines
    
    unset output
EOF

echo "saved $nginx_plt"
