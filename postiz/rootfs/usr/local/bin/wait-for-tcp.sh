#!/usr/bin/env bash
set -e
host="${1:?host required}"
port="${2:?port required}"
timeout="${3:-60}"

deadline=$(( $(date +%s) + timeout ))
while ! (echo >"/dev/tcp/${host}/${port}") 2>/dev/null; do
    if [ "$(date +%s)" -ge "$deadline" ]; then
        echo "wait-for-tcp: ${host}:${port} not reachable after ${timeout}s" >&2
        exit 1
    fi
    sleep 1
done
