#!/usr/bin/env bash

# Setup and configure load balancing simulation through Nginx

if [ $# -eq 0 ]; then
    echo "Usage: ./setup.sh <random|round_robin|least_conn|two_choices> <1..8>"
    exit 1
fi

if [ $2 -gt 8 ]; then
    echo "Error: you can only launch up to 8 servers"
    exit 1
fi

ALGORITHM=$1
NUM_SERVERS=$2

NGINX="/usr/local/nginx/conf/nginx.conf"

TOTAL_REQUESTS=100
CONCURRENT_REQUESTS=10
OUT_FILE="simulations/ab/test.tsv"

################################################################################

echo "generating nginx.conf..."
./simulations/nginx.conf.sh $ALGORITHM $NUM_SERVERS > "$NGINX" || exit 1

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

echo "launching $NUM_SERVERS servers..."
for x in `seq 1 $NUM_SERVERS`; do
    echo "./app -name $x -port 808$x &"
    ./app -name $x -port 808$x &
done

################################################################################

# use apache bench to benchmark server performance
echo "benchmarking..."
sleep 2

ab -n $TOTAL_REQUESTS -c $CONCURRENT_REQUESTS -g $OUT_FILE http://127.0.0.1:8080/ || exit 1

# plot results
# echo "plotting..."

################################################################################

echo "killing all running webservers..."
pkill -f "./app -name" || exit 1

echo "stopping nginx..."
nginx -s stop || exit 1

################################################################################
echo "done."
