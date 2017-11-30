#!/usr/bin/env bash
# run a batch of simulations

function error {
    echo "something went wrong..."
    exit 1
}

function run_sim {
    ./setup.sh $1 $2 $3 $4 || error
    sleep 2
}

# this should be enough data to draw some conclusions from
SIM_DIR="$HOME/Desktop/capstone/simulations/"
PLOT_DIR="$SIM_DIR/plots/tmp/"

# delete any previous ab statistics
if [ -e "$SIM_DIR/ab_data/stats/control.tsv" ]; then
    echo "cleaning ab stats directory..."
    rm "$SIM_DIR/ab_data/stats/*.tsv" || exit 1
fi

for x in 100 500 1000 5000 10000 15000 20000; do
    run_sim 4 $x 10 $PLOT_DIR
done

"./$SIM_DIR/make_stats_plot.sh"

# for req in 500 1000; do
#     for con in 10 50 100; do
#         run_sim 4 $req $con $PLOT_DIR
#         run_sim 8 $req $con $PLOT_DIR
#     done
# done

echo "All Done."
