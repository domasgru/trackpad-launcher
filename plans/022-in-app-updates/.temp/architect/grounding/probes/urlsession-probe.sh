#!/bin/sh
# Starts urlsession-server.py on a local port, runs urlsession-probe.swift against it, stops the server.
HERE=$(cd "$(dirname "$0")" && pwd)
PORT=18765
/usr/bin/python3 -I "$HERE/urlsession-server.py" "$PORT" &
SERVER=$!
sleep 1
swift "$HERE/urlsession-probe.swift" "$PORT"
sleep 1
kill "$SERVER"
wait "$SERVER" 2>/dev/null
