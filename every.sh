#!/bin/bash

# run a command every N seconds
if [ $# -lt 2 ]; then
    echo "Usage: $0 <wait-time> <command> [optional arguments]" >&2
    exit 1
fi

while [ 1 -eq 1 ]; do
    clear
    # TODO: optional arguments?
    $2
    sleep $1
done

