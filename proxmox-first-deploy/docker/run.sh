#!/bin/bash

echo "===== Starting up compose file ====="
docker rm -f {pia,qbittorrent}
docker compose up -d
# docker exec -it gluetun sh -c "apk add --no-cache python3 py3-pip py3-virtualenv bash wget curl && python3 -m venv /tmp/venv && . /tmp/venv/bin/activate && pip install --upgrade pip speedtest-cli && speedtest"
docker logs pia
docker logs qbittorrent
echo "Set qBittorrent's Network Interface to wg0. TODO: set this in deployment playbook."
