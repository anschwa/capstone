#!/usr/bin/env bash

# run a batch of simulations

function error {
    echo "something went wrong..."
    exit 1
}

# this should be enough data to draw some conclusions from
./setup 4 10000 10 || error
./setup 4 10000 50 || error
./setup 4 10000 100 || error

./setup 8 10000 10 || error
./setup 8 10000 50 || error
./setup 8 10000 100 || error
