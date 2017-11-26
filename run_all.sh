#!/usr/bin/env bash

# run a batch of simulations

function error {
    echo "something went wrong..."
    exit 1
}

# this should be enough data to draw some conclusions from
./setup.sh 4 10000 10 || error
./setup.sh 4 10000 50 || error
./setup.sh 4 10000 100 || error

./setup.sh 8 10000 10 || error
./setup.sh 8 10000 50 || error
./setup.sh 8 10000 100 || error
