#!/bin/bash

GETH_RPC="http://127.0.0.1:8545"
PRYSM_RPC="http://127.0.0.1:3500"

PUBLIC_EXEC_RPC="https://ethereum-sepolia-rpc.publicnode.com"
PUBLIC_CONS_RPC="https://ethereum-sepolia-beacon-api.publicnode.com"

GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RESET="\033[0m"

last_public_exec_block=0
last_public_slot=0
last_public_fetch=0
public_interval=30

while true; do
  timestamp=$(date +"[%H:%M:%S]")

  geth_sync=$(curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' $GETH_RPC)

  latest_block=$(curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' $GETH_RPC \
    | jq -r '.result' | xargs printf "%d\n")

  if [[ $geth_sync == *"false"* ]]; then
    geth_status="${GREEN}SYNCED${RESET}"
    currentBlock=$latest_block
    diff=0
  else
    currentBlock=$(echo $geth_sync | jq -r '.result.currentBlock' | xargs printf "%d\n")
    highestBlock=$(echo $geth_sync | jq -r '.result.highestBlock' | xargs printf "%d\n")
    diff=$((highestBlock - currentBlock))
    geth_status="${YELLOW}SYNCING${RESET}"
  fi

  peers=$(curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' $GETH_RPC \
    | jq -r '.result' | xargs printf "%d\n")

  prysm_sync=$(curl -s $PRYSM_RPC/eth/v1/node/syncing)
  is_syncing=$(echo $prysm_sync | jq -r '.data.is_syncing')

  if [[ $is_syncing == "false" ]]; then
    prysm_status="${GREEN}SYNCED${RESET}"
    behind=0
  else
    prysm_status="${YELLOW}SYNCING${RESET}"
    behind=$(echo $prysm_sync | jq -r '.data.sync_distance')
  fi

  head_slot=$(curl -s $PRYSM_RPC/eth/v1/beacon/headers/head \
    | jq -r '.data.header.message.slot')

  now=$(date +%s)
  if (( now - last_public_fetch >= public_interval )); then
    last_public_exec_block=$(curl -s -X POST -H "Content-Type: application/json" \
      --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
      $PUBLIC_EXEC_RPC | jq -r '.result' | xargs printf "%d\n")

    last_public_slot=$(curl -s $PUBLIC_CONS_RPC/eth/v1/beacon/headers/head \
      | jq -r '.data.header.message.slot')

    last_public_fetch=$now
  fi

  printf "%s LOCAL: Geth %-10s | peers:%-3s | %-9s | NET:%-10s (diff:%-6s)\n" \
    "$timestamp" "$currentBlock" "$peers" "$geth_status" "$last_public_exec_block" "$((last_public_exec_block - currentBlock))"

  printf "       Prysm slot:%-10s | %-9s | NET slot:%-10s (behind:%-6s)\n" \
    "$head_slot" "$prysm_status" "$last_public_slot" "$((last_public_slot - head_slot))"

  echo "--------------------------------------------------------------------------------"

  sleep 15
done
