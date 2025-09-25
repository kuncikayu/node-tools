#!/bin/bash
set -e

echo "=== Checking current Docker & Compose version ==="
docker --version || echo "Docker is not installed"
docker compose version 2>/dev/null || docker-compose --version || echo "Docker Compose is not installed"

echo
echo "=== Updating Docker repositories & packages ==="
sudo apt-get update -y
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker’s official GPG key & repo if not already present
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  echo "Adding Docker GPG key..."
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
fi

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo
echo "=== Restarting Docker service ==="
sudo systemctl restart docker

echo
echo "=== Docker & Compose version after update ==="
docker --version
docker compose version 2>/dev/null || docker-compose --version
