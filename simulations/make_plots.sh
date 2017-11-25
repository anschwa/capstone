#!/usr/bin/env bash

# turn all the data files in a directory into plots

IN=$1
OUT=$2
ALGORITHM=$3
SERVERS=$4
CON=$5

if [ $# -lt 5 ]; then
    echo "usage: ./plot.sh <datafiles directory> <plots directory> <algorithm> <servers> <concurrency>"
    exit 1
fi

echo "plotting all data files in '$IN' to '$OUT'..."

for x in "$IN"/*; do
    
    plt=$(basename "$x" .tsv)

    gnuplot <<EOF
        set terminal png size 500, 500 noenhanced
        set size 1, 1
        
        set title "Apache Bench on Nginx using $ALGORITHM\n $SERVERS Server(s) and $CON Concurrent Connections"
        set grid y
        set xlabel "Number of Requests"
        set ylabel "Response Time (ms)"

        set datafile separator '\t'
        
        set output "$OUT/$plt.png"
        plot "$x" every ::2 using 5 notitle with lines
EOF

echo "saved $OUT$plt.png"

done
