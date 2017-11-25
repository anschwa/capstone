#!/usr/bin/env bash

# Setup and configure load balancing simulation through Nginx

if [ $# -lt 4 ]; then
    echo "Usage: ./setup.sh <random|round_robin|least_conn|two_choices> <servers: 1..8> <requests> <concurrent>"
    exit 1
fi

if [ $2 -gt 8 ]; then
    echo "Error: you can only launch up to 8 servers"
    exit 1
fi

ALGORITHM=$1
SERVERS=$2

# path to nginx.conf
NGINX="/usr/local/nginx/conf/nginx.conf"

TOTAL_REQUESTS=$3
CONCURRENT_REQUESTS=$4

# for gnuplot      
DATA_DIR="simulations/ab_data/$ALGORITHM/"
PLOT_DIR="simulations/plots/$ALGORITHM/"

for x in random round_robin least_conn two_choices; do
    mkdir -p "simulations/ab_data/$x"
    mkdir -p "simulations/plots/$x"
done

################################################################################

echo "generating nginx.conf..."
./simulations/nginx.conf.sh $ALGORITHM $SERVERS > "$NGINX" || exit 1

echo "launching nginx..."
nginx || exit 1

echo "testing nginx configuration..."
nginx -t || exit 1

# reload
nginx -s reload || exit 1

################################################################################

# Launch webservers
if [ ! -x "app" ]; then
    echo "building webserver..."
    go build src/server/app.go || exit 1
fi

echo "launching $SERVERS servers..."
for x in `seq 1 $SERVERS`; do
    echo "./app -name $x -port 808$x &"
    ./app -name $x -port 808$x &
done

################################################################################

# use apache bench to benchmark server performance
ab_output="$DATA_DIR/$(date +%s).tsv"

echo "Benchmarking to $ab_output..."
sleep 2

ab -n $TOTAL_REQUESTS -c $CONCURRENT_REQUESTS -g $ab_output http://127.0.0.1:8080/ || exit 1

################################################################################

echo "killing all running webservers..."
pkill -f "./app -name" || exit 1

echo "stopping nginx..."
nginx -s stop || exit 1

################################################################################

echo "setting up gnuplot"
./simulations/make_plots.sh "$DATA_DIR" "$PLOT_DIR" "$ALGORITHM" "$SERVERS" "$CONCURRENT_REQUESTS"

################################################################################

echo "done."
