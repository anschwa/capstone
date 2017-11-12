# http://www.bradlanders.com/2013/04/15/apache-bench-and-gnuplot-youre-probably-doing-it-wrong/

set terminal png size 500,500
# This sets the aspect ratio of the graph
set size 1, 1

set output "plot.png"

set title "Benchmark testing"
set key left top
set grid y
set xlabel 'requests'
set ylabel "response time (ms)"

set datafile separator '\t'

# Plot the data
plot "ab.tsv" every ::2 using 5 title 'response time' with lines