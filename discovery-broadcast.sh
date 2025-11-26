#!/usr/bin/env bash
# discovery-broadcast.sh
# Broadcast worker presence every 3 seconds

PORT=9911
NAME=$(hostname)
IP=$(hostname -I | awk '{print $1}')

while true; do
    MSG="WORKER:$NAME:$IP"
    echo -n "$MSG" | nc -u -w1 255.255.255.255 $PORT
    sleep 3
done

