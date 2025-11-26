#!/usr/bin/env bash
# run_cluster.sh
# Load workers from AutoNet discovery list

WORKERLIST="workers.lst"
PORT=5544

echo "[CLUSTER] Warte auf Worker..."
sleep 2

echo "[CLUSTER] Gefundene Worker:"
cat "$WORKERLIST"

while read -r IP; do
    echo "[CLUSTER] Starte Worker: $IP"
    echo "$1" | nc "$IP" $PORT
done < "$WORKERLIST"

