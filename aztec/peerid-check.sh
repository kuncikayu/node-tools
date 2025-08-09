#!/bin/bash

#############################################
#  AZTEC NODE PEERID & LOCATION CHECKER
#  Author: Keywood
#############################################

clear

# ==== COLORS ====
C_RESET="\033[0m"
C_GREEN="\033[32m"
C_RED="\033[31m"
C_BLUE="\033[34m"
C_YELLOW="\033[33m"
C_CYAN="\033[36m"
C_PURPLE="\033[35m"

# ==== BANNER ====
echo -e "${C_PURPLE}"
echo "=========================================="
echo "   🌑 AZTEC NODE PEERID & LOCATION CHECK  "
echo "=========================================="
echo -e "${C_RESET}"

# ==== STEP 1: Get PeerID from 'aztec' container logs ====
peerid=$(sudo docker logs $(docker ps -q --filter "name=aztec" | head -1) 2>&1 \
  | grep -m 1 -ai 'DiscV5 service started' \
  | grep -o '"peerId":"[^"]*"' \
  | cut -d'"' -f4)

# ==== STEP 2: Try any running container with 'aztec' image if not found ====
if [ -z "$peerid" ]; then
  container_id=$(sudo docker ps \
    --filter "ancestor=$(sudo docker images --format '{{.Repository}}:{{.Tag}}' | grep aztec | head -1)" \
    -q | head -1)
  if [ -n "$container_id" ]; then
    peerid=$(sudo docker logs $container_id 2>&1 \
      | grep -m 1 -ai 'DiscV5 service started' \
      | grep -o '"peerId":"[^"]*"' \
      | cut -d'"' -f4)
  fi
fi

# ==== STEP 3: Last resort - any 'peerId' log in container name with aztec ====
if [ -z "$peerid" ]; then
  peerid=$(sudo docker logs $(docker ps -q --filter "name=aztec" | head -1) 2>&1 \
    | grep -m 1 -ai '"peerId"' \
    | grep -o '"peerId":"[^"]*"' \
    | cut -d'"' -f4)
fi

# ==== DISPLAY RESULT ====
if [ -n "$peerid" ]; then
  label=" ● PeerID"
  peerline="✓ $peerid"
  width=${#peerline}
  [ ${#label} -gt $width ] && width=${#label}
  line=$(printf '=%.0s' $(seq 1 $width))

  echo "$line"
  echo -e "$label"
  echo -e "${C_GREEN}$peerline${C_RESET}"
  echo "$line"
  echo

  echo -e "${C_BLUE}Fetching stats from Nethermind Aztec Explorer...${C_RESET}"
  response=$(curl -s "https://aztec.nethermind.io/api/peers?page_size=30000&latest=true")

  stats=$(echo "$response" | jq -r --arg peerid "$peerid" '
    .peers[] | select(.id == $peerid) |
    [
      .last_seen,
      .created_at,
      .multi_addresses[0].ip_info[0].country_name,
      (.multi_addresses[0].ip_info[0].latitude | tostring),
      (.multi_addresses[0].ip_info[0].longitude | tostring)
    ] | @tsv
  ')

  if [ -n "$stats" ]; then
    IFS=$'\t' read -r last first country lat lon <<<"$stats"
    last_local=$(date -d "$last" "+%Y-%m-%d - %H:%M" 2>/dev/null || echo "$last")
    first_local=$(date -d "$first" "+%Y-%m-%d - %H:%M" 2>/dev/null || echo "$first")

    printf "%-12s: %s\n" "Last Seen"   "${C_CYAN}$last_local${C_RESET}"
    printf "%-12s: %s\n" "First Seen"  "${C_CYAN}$first_local${C_RESET}"
    printf "%-12s: %s\n" "Country"     "${C_YELLOW}$country${C_RESET}"
    printf "%-12s: %s\n" "Latitude"    "${C_PURPLE}$lat${C_RESET}"
    printf "%-12s: %s\n" "Longitude"   "${C_PURPLE}$lon${C_RESET}"
  else
    echo -e "${C_RED}No stats found for this PeerID on Nethermind Aztec Explorer.${C_RESET}"
  fi
else
  echo -e "${C_RED}❌ No Aztec PeerID found.${C_RESET}"
fi
