#!/bin/bash
set -e

echo "=== Checking currently installed Go version (if any) ==="
if command -v go >/dev/null 2>&1; then
  go version
else
  echo "Go is not installed yet."
fi

echo
echo "=== Fetching latest Go version from go.dev ==="
LATEST_VERSION=$(curl -s https://go.dev/dl/?mode=json | grep -m1 '"version":' | sed -E 's/.*"go([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
  echo "Failed to fetch latest Go version."
  exit 1
fi

echo "Latest Go version available: $LATEST_VERSION"

DOWNLOAD_URL="https://go.dev/dl/go${LATEST_VERSION}.linux-amd64.tar.gz"
TMP_FILE="/tmp/go${LATEST_VERSION}.linux-amd64.tar.gz"

echo
echo "=== Downloading Go ${LATEST_VERSION} ==="
wget -q $DOWNLOAD_URL -O $TMP_FILE

echo "=== Removing old Go installation ==="
sudo rm -rf /usr/local/go

echo "=== Extracting Go to /usr/local ==="
sudo tar -C /usr/local -xzf $TMP_FILE

echo "=== Adding Go to PATH if not already present ==="
if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
  echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
fi

echo "=== Reloading shell environment ==="
source ~/.bashrc

echo "=== Cleaning up downloaded archive ==="
rm -f $TMP_FILE

echo
echo "=== Go updated successfully! Installed version: ==="
go version
