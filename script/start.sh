#!/bin/bash

echo "Starting/Restarting BBSConnectionGateway..."
echo "Killing any existing process..."
pkill -f 'script/bbscg'

echo "Checking if dependencies need to be updated..."
cpanm --installdeps -n .

PWD=`pwd`
STDOUT_LOG=../logs/bbscg_server.log

echo "Starting BBSConnectionGateway..."
nohup ${PWD}/script/bbscg >> $STDOUT_LOG 2>&1 &

echo "BBSConnectionGateway startup complete."
