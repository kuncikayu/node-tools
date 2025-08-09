#!/bin/bash

# ===============================================
#  GETH & PRYSM ETHEREUM NODE SYNC STATUS CHECKER
# ===============================================

# ==== COLORS ====
C_RESET="\033[0m"
C_GREEN="\033[32m"
C_RED="\033[31m"
C_BLUE="\033[34m"
C_YELLOW="\033[33m"
C_CYAN="\033[36m"

for cmd in curl jq; do
  if ! command -v $cmd &> /dev/null; then
    echo -e "${C_RED}Error: Command '$cmd' not found. Please install it first.${C_RESET}"
    exit 1
  fi
done

echo -e "${C_BLUE}=====================================${C_RESET}"
echo -e "${C_CYAN} Ethereum Node Sync Status Checker ${C_RESET}"
echo -e "${C_BLUE}=====================================${C_RESET}"
echo "This script will prompt you to enter the Geth and Prysm ports."
echo "Press [ENTER] to use the default values."
echo ""

read -p "Enter the Geth RPC port (default: 8545): " GETH_PORT
GETH_PORT=${GETH_PORT:-8545}

read -p "Enter the Prysm Beacon API port (default: 3500): " PRYSM_PORT
PRYSM_PORT=${PRYSM_PORT:-3500}

echo ""
echo "------------------------------------------------"
echo -e "Using Geth port: ${C_YELLOW}$GETH_PORT${C_RESET}"
echo -e "Using Prysm port: ${C_YELLOW}$PRYSM_PORT${C_RESET}"
echo "------------------------------------------------"
echo ""

echo -e "${C_CYAN}=== GETH SYNC STATUS (Port: $GETH_PORT) ===${C_RESET}"
geth_response=$(curl -s -f -X POST --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  -H "Content-Type: application/json" "http://localhost:${GETH_PORT}")

if [ $? -ne 0 ]; then
    echo -e "${C_RED}Failed to connect to Geth on port $GETH_PORT. Make sure Geth is running and the port is correct.${C_RESET}"
else
    echo "$geth_response" | jq
fi

echo ""

echo -e "${C_CYAN}=== PRYSM SYNC STATUS (Port: $PRYSM_PORT) ===${C_RESET}"
prysm_response=$(curl -s -f "http://localhost:${PRYSM_PORT}/eth/v1/node/syncing")

if [ $? -ne 0 ]; then
    echo -e "${C_RED}Failed to connect to Prysm on port $PRYSM_PORT. Make sure the Prysm Beacon Node is running and the port is correct.${C_RESET}"
else
    echo "$prysm_response" | jq
fi

echo ""