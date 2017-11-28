#!/usr/bin/env bash

echo "Killing nginx and webservers..."
pkill -f "./app -name"
pkill -f nginx
