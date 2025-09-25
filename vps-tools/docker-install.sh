#!/bin/bash
set -e

echo "=== Removing old Docker versions (if any) ==="
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true

echo
echo "=== Updating repositories ==="
sudo apt-get update -y
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

echo
echo "=== Adding Docker GPG key ==="
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo
echo "=== Setting up Docker repository ==="
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo
echo "=== Installing Docker Engine & Compose ==="
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo
echo "=== Enabling and starting Docker service ==="
sudo systemctl enable docker
sudo systemctl start docker

echo
echo "=== Docker & Compose installed successfully ==="
docker --version
docker compose version
