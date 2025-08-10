#!/bin/bash

read -p "Enter the port number to check: " PORT

IP=$(curl -s ifconfig.me)

echo "============================"
echo "Checking Port: $PORT"
echo "Public IP: $IP"
echo "============================"

if sudo lsof -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; then
    echo "[Local Test]    : OPEN"
else
    echo "[Local Test]    : CLOSED"
fi

PUBLIC_RESULT=$(curl -s -X POST "https://ports.yougetsignal.com/check-port.php" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data "remoteAddress=$IP&portNumber=$PORT")

if echo "$PUBLIC_RESULT" | grep -qi "is open"; then
    echo "[Public Test]   : OPEN"
elif echo "$PUBLIC_RESULT" | grep -qi "is closed"; then
    echo "[Public Test]   : CLOSED"
else
    echo "[Public Test]   : UNKNOWN"
fi
