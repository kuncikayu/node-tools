#!/bin/bash

GETH_RPC="http://127.0.0.1:8545"
PRYSM_RPC="http://127.0.0.1:3500"
PUBLIC_EXEC_RPC="https://ethereum-sepolia-rpc.publicnode.com"
PUBLIC_CONS_RPC="https://ethereum-sepolia-beacon-api.publicnode.com"

C_RESET="\033[0m"
C_GREEN="\033[32m"
C_RED="\033[31m"
C_BLUE="\033[34m"
C_YELLOW="\033[33m"
C_CYAN="\033[36m"

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
    geth_status="${C_GREEN}SYNCED${C_RESET}"
    currentBlock=$latest_block
    diff=0
  else
    currentBlock=$(echo $geth_sync | jq -r '.result.currentBlock' | xargs printf "%d\n")
    highestBlock=$(echo $geth_sync | jq -r '.result.highestBlock' | xargs printf "%d\n")
    diff=$((highestBlock - currentBlock))
    geth_status="${C_YELLOW}SYNCING${C_RESET}"
  fi

  peers=$(curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' $GETH_RPC \
    | jq -r '.result' | xargs printf "%d\n")

  prysm_sync=$(curl -s $PRYSM_RPC/eth/v1/node/syncing)
  is_syncing=$(echo $prysm_sync | jq -r '.data.is_syncing')

  if [[ $is_syncing == "false" ]]; then
    prysm_status="${C_GREEN}SYNCED${C_RESET}"
    behind=0
  else
    prysm_status="${C_YELLOW}SYNCING${C_RESET}"
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

  if (( diff == 0 )); then
    diff_color=$C_GREEN
  else
    diff_color=$C_RED
  fi

  if (( behind == 0 )); then
    behind_color=$C_GREEN
  else
    behind_color=$C_RED
  fi

  echo -e "$timestamp ${C_BLUE}LOCAL:${C_RESET} Geth ${C_YELLOW}$currentBlock${C_RESET} | peers:${C_CYAN}$peers${C_RESET} | $geth_status | NET:${C_GREEN}$last_public_exec_block${C_RESET} (diff:${diff_color}$diff${C_RESET})"
  echo -e "       Prysm slot:${C_YELLOW}$head_slot${C_RESET} | $prysm_status | NET slot:${C_GREEN}$last_public_slot${C_RESET} (behind:${behind_color}$behind${C_RESET})"
  echo    "--------------------------------------------------------------------------------"

  sleep 5
done
