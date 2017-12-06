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

DATA_DIR="data/ab/"
STATS_DIR="data/stats/"

mkdir -p "$DATA_DIR"
mkdir -p "$STATS_DIR"

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
ab_data="$DATA_DIR/$ALGORITHM.tsv"
ab_stats="$STATS_DIR/$ALGORITHM.tsv"

# clear out old trial data
if [ -e "$ab_data" ]; then
    rm "$ab_data"
fi

# if [ -e "$ab_stats" ]; then
#     rm "$ab_stats"
# fi

# create new ab stats file
if [ ! -e "$ab_stats" ]; then
    printf "requests\tconcurrent\tmin\tmean\t[+/-sd]\tmedian\tmax\n" > "$ab_stats"
fi

echo "Benchmarking $ALGORITHM to $ab_data."
echo "Redirecting ab to $ab_stats..."
sleep 2

ab -n $REQUESTS -c $CONCURRENT -g "$ab_data" http://127.0.0.1:8080/ | ./parse_ab.py "$REQUESTS" "$CONCURRENT" >> "$ab_stats" || exit 1

################################################################################

echo "killing all running webservers..."
pkill -f "./app -name" || exit 1

echo "stopping nginx..."
nginx -s stop || exit 1

################################################################################

echo "done."
