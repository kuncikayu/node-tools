#!/bin/bash

########################################
# Aztec Node Sync Watcher
# Author: Keywood
########################################

# ==== CONFIG ====
LOCAL_PORT=8080
REMOTE_RPC="https://rpc-aztec.keywood.site"
CHECK_INTERVAL=10

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
    echo "       🌑 AZTEC NODE SYNC MONITOR 🌑       "
    echo "=========================================="
    echo -e "${C_RESET}"
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

    now=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${C_BLUE}[$now]${C_RESET}"

    echo -e "   🧱 Local Block : ${C_CYAN}${local_block:-N/A}${C_RESET}"
    echo -e "   🌍 Remote Block: ${C_GREEN}${remote_block:-N/A}${C_RESET}"

    sync_pct=$(percent "$local_block" "$remote_block")
    echo -n "   📊 Status      : "
    status_line "$sync_pct"

    echo "------------------------------------------"
    sleep $CHECK_INTERVAL
done
