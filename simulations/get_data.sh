#!/usr/bin/env bash

# gather benchmarking data for all load balancing algorithms, launch the webservers, and configure Nginx

if [ $# -lt 4 ]; then
    echo "Usage: ./get_data.sh <random|round_robin|least_conn|two_choices|control> <servers: 1..8> <requests> <concurrent>"
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

DATA_DIR="ab_data/$ALGORITHM/"

# create data file directories 
for x in random round_robin least_conn two_choices control; do
    mkdir -p "ab_data/$x"
done

################################################################################

echo "generating nginx.conf..."
./nginx.conf.sh $ALGORITHM $SERVERS > "$NGINX" || exit 1

echo "launching nginx..."
nginx || exit 1

echo "testing nginx configuration..."
nginx -t || exit 1

# reload
nginx -s reload || exit 1

################################################################################

# Launch webservers
if [ ! -x "app" ]; then
    echo "Error: webserver not found"
    exit 1
fi

echo "launching $SERVERS servers..."
for x in `seq 1 $SERVERS`; do
    echo "./app -name $x -port 808$x &"
    ./app -name $x -port 808$x &
done

################################################################################

# use apache bench to benchmark server performance
ab_output="$DATA_DIR/$ALGORITHM.tsv"
ab_archive="$DATA_DIR/$ALGORITHM-$(date +%s).tsv"

# archive old trials by renaming before new data is created
if [ -e "$ab_output" ]; then
    mv "$ab_output" "$ab_archive"
fi

echo "Benchmarking to $ab_output..."
sleep 2

ab -n $TOTAL_REQUESTS -c $CONCURRENT_REQUESTS -g $ab_output http://127.0.0.1:8080/ || exit 1

################################################################################

echo "killing all running webservers..."
pkill -f "./app -name" || exit 1

echo "stopping nginx..."
nginx -s stop || exit 1

################################################################################

echo "done."
