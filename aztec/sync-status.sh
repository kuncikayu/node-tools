#!/bin/bash

########################################
# Aztec Node Sync Watcher 
# Author: Keywood
########################################

read -p "Please enter the local port for your Aztec node (default: 8080): " LOCAL_PORT
LOCAL_PORT=${LOCAL_PORT:-8080}

# ==== CONFIG ====
REMOTE_RPC="https://rpc-aztec.keywood.site"
AZTECSCAN_API_KEY="temporary-api-key"
AZTECSCAN_API_URL="https://api.testnet.aztecscan.xyz/v1/${AZTECSCAN_API_KEY}/l2/ui/blocks-for-table"
CHECK_INTERVAL=30

# ==== COLORS ====
C_RESET="\033[0m"
C_RED="\033[31m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_BLUE="\033[34m"
C_PURPLE="\033[35m"
C_CYAN="\033[36m"

# ==== FUNCTIONS ====

banner() {
    echo -e "${C_PURPLE}"
    echo "=========================================="
    echo "    🌑 AZTEC NODE SYNC MONITOR By: Key    "
    echo "=========================================="
    echo -e "${C_RESET}"
    echo -e "   📍 Lokal Port : ${C_CYAN}$LOCAL_PORT${C_RESET}"
    echo -e "   🌍 Remote RPC : ${C_GREEN}$REMOTE_RPC${C_RESET}"
    echo
}

get_local_block() {
    curl -s -X POST -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":1}' \
    http://localhost:$LOCAL_PORT | jq -r ".result.proven.number" 2>/dev/null
}

get_remote_block() {
    curl -s -X POST -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":1}' \
    $REMOTE_RPC | jq -r ".result.proven.number" 2>/dev/null
}

get_aztecscan_block() {
    local BATCH_SIZE=20
    local LATEST_BLOCK=$(curl -s "$AZTECSCAN_API_URL?from=0&to=0" | jq -r '.[0].height')
    if [[ -z "$LATEST_BLOCK" || "$LATEST_BLOCK" == "null" ]]; then
        echo "N/A"
        return
    fi
    local CURRENT_HEIGHT=$LATEST_BLOCK
    while true; do
        local FROM_HEIGHT=$((CURRENT_HEIGHT - BATCH_SIZE + 1))
        [ $FROM_HEIGHT -lt 0 ] && FROM_HEIGHT=0
        local MATCH=$(curl -s "$AZTECSCAN_API_URL?from=$FROM_HEIGHT&to=$CURRENT_HEIGHT" \
            | jq -r '.[] | select(.blockStatus == 4) | .height' \
            | sort -nr | head -n1)
        if [[ -n "$MATCH" && "$MATCH" != "null" ]]; then
            echo "$MATCH"
            return
        fi
        CURRENT_HEIGHT=$((FROM_HEIGHT - 1))
        [ $CURRENT_HEIGHT -lt 0 ] && echo "N/A" && return
    done
}

percent() {
    if [[ "$1" =~ ^[0-9]+$ ]] && [[ "$2" =~ ^[0-9]+$ ]] && [ "$2" -ne 0 ]; then
        echo $(( 100 * $1 / $2 ))
    else
        echo "N/A"
    fi
}

status_line() {
    local pct=$1
    if [ "$pct" = "N/A" ]; then
        echo -e "${C_RED}❌ Unable to calculate sync${C_RESET}"
    elif [ "$pct" -eq 100 ]; then
        echo -e "${C_GREEN}✅ Fully Synced${C_RESET}"
    elif [ "$pct" -ge 90 ]; then
        echo -e "${C_GREEN}🎯 Almost Synced ($pct%)${C_RESET}"
    elif [ "$pct" -ge 50 ]; then
        echo -e "${C_CYAN}📈 Good Progress ($pct%)${C_RESET}"
    else
        echo -e "${C_YELLOW}⏳ Syncing... ($pct%)${C_RESET}"
    fi
}

# ==== MAIN LOOP ====
banner
while true; do
    local_block=$(get_local_block)
    remote_block=$(get_remote_block)
    aztecscan_block=$(get_aztecscan_block)

    now=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${C_BLUE}[$now]${C_RESET}"

    echo -e "   🧱 Local Block    : ${C_CYAN}${local_block:-N/A}${C_RESET}"
    echo -e "   🌍 Remote RPC     : ${C_GREEN}${remote_block:-N/A}${C_RESET}"
    echo -e "   📡 AztecScan API  : ${C_PURPLE}${aztecscan_block:-N/A}${C_RESET}"

    if [[ "$aztecscan_block" != "N/A" ]]; then
        sync_pct=$(percent "$local_block" "$aztecscan_block")
        echo -n "   📊 Status vs AztecScan : "
        status_line "$sync_pct"
    fi

    if [[ "$remote_block" != "N/A" ]]; then
        sync_pct2=$(percent "$local_block" "$remote_block")
        echo -n "   📊 Status vs RemoteRPC : "
        status_line "$sync_pct2"
    fi

    echo "------------------------------------------"
    sleep $CHECK_INTERVAL
done
