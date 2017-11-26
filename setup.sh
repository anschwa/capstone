#!/usr/bin/env bash

# setup and run a load balancing simulation using Go, Nginx, Apache Bench, and Gnuplot

if [ $# -lt 3 ]; then
    echo "Usage: ./setup.sh <servers: 1..8> <requests> <concurrent>"
    exit 1
fi

if [ $1 -gt 8 ]; then
    echo "Error: you can only launch up to 8 servers"
    exit 1
fi

echo "Starting Simulation..."

SERVERS=$1
REQUESTS=$2
CONCURRENT=$3

if [ ! -x "simulations/app" ]; then
    echo "building webserver..."
    go build -o simulations/app src/server/app.go || exit 1
fi

path=$(pwd)
cd simulations/

# backup existing log file
log="logs/simulation.log"
log_bak="logs/simulation-$(date +%s).log"

if [ -e "$log" ]; then
    mv "$log" "$log_bak"
fi

# create a new log file
echo "Load Balancing Simulation Log File" > "$log"
echo "Servers: $SERVERS. Total Requests: $REQUESTS. Concurrent Requests: $CONCURRENT." >> "$log"
echo "--------------------------------------------------------------------------------" >> "$log"

function error {
    echo "Error: Check simulations/logs/simulation.log"
    exit 1
}

################################################################################

echo "Establishing a control (only 1 server)..."
./get_data.sh control 1 "$REQUESTS" "$CONCURRENT" &>> "$log" || error

echo "Benchmarking round_robin..."
./get_data.sh round_robin "$SERVERS" "$REQUESTS" "$CONCURRENT" &>> "$log" || error

echo "Benchmarking least_conn..."
./get_data.sh least_conn "$SERVERS" "$REQUESTS" "$CONCURRENT" &>> "$log" || error

echo "Benchmarking random..."
./get_data.sh random "$SERVERS" "$REQUESTS" "$CONCURRENT" &>> "$log" || error

echo "Benchmarking two_choices..."
./get_data.sh two_choices "$SERVERS" "$REQUESTS" "$CONCURRENT" &>> "$log" || error

################################################################################

echo "Creating plot..."
./make_plot.sh "$SERVERS" "$REQUESTS" "$CONCURRENT" &>> "$log" || error

################################################################################

cd "$path"

echo "Done. You can examine simulations/logs/ for more information."
