# http://www.bradlanders.com/2013/04/15/apache-bench-and-gnuplot-youre-probably-doing-it-wrong/

set terminal png size 500,500
# This sets the aspect ratio of the graph
set size 1, 1

set output "plot.png"

set title "Benchmark testing"
set key left top
set grid y

# Specify the *input* format of the time data
set timefmt "%s"

# Specify that the x-series data is time data
set xdata time

# Specify the *output* format for the x-axis tick labels
set format x "%S"

set xlabel 'seconds'
set ylabel "response time (ms)"
 
set datafile separator '\t'

# Plot the data
plot "ab.tsv" every ::2 using 2:5 title 'response time' with points