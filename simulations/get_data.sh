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

REQUESTS=$3
CONCURRENT=$4

DATA_DIR="ab_data/data/$ALGORITHM/"
STATS_DIR="ab_data/stats/"

mkdir -p "$DATA_DIR"
mkdir -p "$STATS_DIR"

# create data file directories
for x in random round_robin least_conn two_choices control; do
    mkdir -p "ab_data/data/$x"
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
ab_tsv="$DATA_DIR/$ALGORITHM.tsv"
tsv_archive="$DATA_DIR/$ALGORITHM-$(date +%s).tsv"

ab_stats="$STATS_DIR/$ALGORITHM.tsv"

# initialize this file if it doesn't exist
if [ ! -e "$ab_stats" ]; then
    printf "min\tmean\t[+/-sd]\tmedian\tmax\n" > "$ab_stats"
fi

# archive old trials by renaming before new data is created
if [ -e "$ab_tsv" ]; then
    mv "$ab_tsv" "$tsv_archive"
fi

echo "Benchmarking $ALGORITHM to $ab_tsv."
echo "Redirecting ab to $ab_stats..."
sleep 2

ab -n $REQUESTS -c $CONCURRENT -g "$ab_tsv" http://127.0.0.1:8080/ | ./ab_parse.py >> "$ab_stats" || exit 1

################################################################################

echo "killing all running webservers..."
pkill -f "./app -name" || exit 1

echo "stopping nginx..."
nginx -s stop || exit 1

################################################################################

echo "done."
