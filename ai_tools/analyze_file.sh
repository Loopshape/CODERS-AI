#!/bin/bash
FILE="$1"
if [[ -z "$FILE" || ! -f "$FILE" ]]; then
    echo "Usage: $0 <file>"
    exit 1
fi
echo "AI File Analysis Tool"
echo "File: $FILE"
echo "Type: $(file -b "$FILE")"
echo "Size: $(stat -c%s "$FILE") bytes"
