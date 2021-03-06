#!/usr/bin/env bash
# generate an nginx.conf with the correct settings
# usage: ./nginx.conf.sh <random|round_robin|least_conn|two_choices|control> <number of servers>

if [ "$1" = "round_robin" ] || [ "$1" = "control" ]; then
    ALGORITHM=""
else
  ALGORITHM="$1;"
fi

NUM_SERVERS=$2

SERVERS=""
for x in `seq 1 ${NUM_SERVERS}`; do
    tmp="server localhost:808$x;"
    SERVERS+="$tmp"
done

cat <<EOF
# Senior Capstone Nginx Config
# Adam Schwartz Fall 2017
# 
# symlink to system nginx.conf location to use
# ln -s nginx_dev.conf /usr/local/nginx/conf/nginx.conf
#

# load my load balancer modules
load_module modules/ngx_http_upstream_random_module.so;
load_module modules/ngx_http_upstream_two_choices_module.so;

#user  nobody;
worker_processes  1;            # run nginx on 1 core

# increase resource limit
worker_rlimit_nofile 65535;

# add debuging log
error_log logs/debug.log debug;

#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

pid        logs/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    #log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    #                  '$status $body_bytes_sent "$http_referer" '
    #                  '"$http_user_agent" "$http_x_forwarded_for"';

    #access_log  logs/access.log  main;
    access_log off;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  15;

    # add load balancer
    upstream myapp {
        ${ALGORITHM}
        ${SERVERS}
    }

    server {
        listen       8080;
        server_name  localhost;

        location / {
            proxy_pass http://myapp;
        }

        #error_page  404              /404.html;

        # redirect server error pages to the static page /50x.html
        #
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }
}
EOF
