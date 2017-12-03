#!/usr/bin/env bash

# setup and run a load balancing simulation using Go, Nginx, Apache Bench, and Gnuplot

if [ $# -lt 3 ]; then
    echo "Usage: ./setup.sh <servers: 1..8> <requests> <concurrent> [plot directory]"
    echo "example: ./setup.sh 4 1000 10 simulation/plots/trialA/"
    echo "the default plot output directory is simulations/plots/"
    exit 1
fi

if [ $1 -gt 8 ]; then
    echo "Error: you can only launch up to 8 servers"
    exit 1
fi

SERVERS="$1"
REQUESTS="$2"
CONCURRENT="$3"
PLOT_DIR="$4"

################################################################################

echo "$SERVERS servers, $REQUESTS total requests, $CONCURRENT concurrent"
echo "Starting Simulation..."

if [ ! -x "simulations/app" ]; then
    echo "building webserver..."
    go build -o simulations/app src/server/app.go || exit 1
fi

path=$(pwd)
cd "simulations/"

# set default plot directory if none is specified
if [ "$PLOT_DIR" = "" ]; then
    PLOT_DIR="plots/"
else
    mkdir -p $PLOT_DIR || exit 1
fi

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

echo "Creating ab and stats plot in '$PLOT_DIR'..."
./make_plot.sh "$SERVERS" "$REQUESTS" "$CONCURRENT" "$PLOT_DIR" &>> "$log" || error

./make_box_plot.sh "$SERVERS" "$REQUESTS" "$CONCURRENT" "$PLOT_DIR" &>> "$log" || error

################################################################################

cd "$path"

echo "Done. You can examine simulations/logs/ for more information."
