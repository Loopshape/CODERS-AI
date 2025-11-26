#!/usr/bin/env bash
# discovery-listen.sh
# Listen to UDP beacons and maintain worker list

PORT=9911
LIST=workers.lst

# reset list
> "$LIST"

# incoming format: WORKER:<hostname>:<ip>

nc -u -l -p $PORT | while read -r line; do
    if [[ "$line" =~ ^WORKER: ]]; then
        IFS=":" read -r _ NAME IP <<< "$line"

        # update or add entry
        if ! grep -q "$IP" "$LIST"; then
            echo "$IP" >> "$LIST"
            echo "[DISCOVERY] neue Worker-IP: $IP"
        fi
    fi
done

