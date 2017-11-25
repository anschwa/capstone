# make a combined benchmark plot for all algorithms

set terminal png size 500, 500 noenhanced
set size 1, 1
        
set grid y

set title "Comparing Load Balancing Algorithms on Nginx\n4 Server(s) and 10 Concurrent Connections"
set xlabel "Percentage of Requests Served out of 10,000"
set ylabel "Response Time for Completion (ms)"

set datafile separator '\t'
set output "out.png"

plot "control.tsv" every ::2 using ($0*.01):5 title "control" with lines, \
"round_robin/round_robin_avg.tsv" every ::2 using ($0*.01):5 title "round robin" with lines, \
"least_conn/least_conn_avg.tsv" every ::2 using ($0*.01):5 title "least conn" with lines, \
"random/random_avg.tsv" every ::2 using ($0*.01):5 title "random" with lines, \
"two_choices/two_choices_avg.tsv" every ::2 using ($0*.01):5 title "two choices" with lines, \
"apple.tsv" every ::2 using ($0*.01):5 title "apple.com" with lines, \
"google.tsv" every ::2 using ($0*.01):5 title "google.com" with lines, \
"microsoft.tsv" every ::2 using ($0*.01):5 title "microsoft.com" with lines
