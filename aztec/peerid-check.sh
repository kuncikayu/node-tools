#!/bin/bash

#############################################
#  AZTEC NODE PEERID & LOCATION CHECKER
#  Author: Keywood
#############################################

cleanup_and_exit() {
  echo -e "\n${C_RESET}Script interrupted."
  exit 1
}
trap cleanup_and_exit INT TERM

# ==== COLORS ====
C_RESET=$'\033[0m'
C_GREEN=$'\033[32m'
C_RED=$'\033[31m'
C_BLUE=$'\033[34m'
C_YELLOW=$'\033[33m'
C_CYAN=$'\033[36m'
C_PURPLE=$'\033[35m'

clear

# ==== BANNER ====
echo -e "${C_PURPLE}"
echo "=========================================="
echo "   🌑 AZTEC NODE PEERID & LOCATION CHECK  "
echo "=========================================="
echo -e "${C_RESET}"

# ==== STEP 0: Dependency Check ====
echo -e "${C_BLUE}Checking dependencies (docker, jq, curl)...${C_RESET}"
for cmd in docker jq curl; do
  if ! command -v $cmd &> /dev/null; then
    echo -e "${C_RED}❌ Error: Command '$cmd' not found. Please install it first.${C_RESET}"
    exit 1
  fi
done
echo -e "${C_GREEN}✓ Dependencies satisfied.${C_RESET}\n"

# ==== STEP 1: Find Running Aztec Containers ====
echo -e "${C_BLUE}Searching for active Aztec containers...${C_RESET}"
container_ids=$( { sudo docker ps -q --filter "name=aztec"; \
                   sudo docker ps -q --filter "ancestor=aztecprotocol/aztec-node"; } | sort -u )

if [ -z "$container_ids" ]; then
  echo -e "${C_RED}❌ No running Aztec Docker containers found.${C_RESET}"
  exit 1
fi

# ==== STEP 2: Extract PeerID from Container Logs ====
peerid=""
for id in $container_ids; do
  echo -e "Trying container ID: ${C_YELLOW}${id}${C_RESET}..."
  peerid=$(sudo docker logs "$id" 2>&1 | grep -m 1 -ai 'DiscV5 service started' | grep -o '"peerId":"[^"]*"' | cut -d'"' -f4)
  if [ -z "$peerid" ]; then
    peerid=$(sudo docker logs "$id" 2>&1 | grep -m 1 -ai '"peerId"' | grep -o '"peerId":"[^"]*"' | cut -d'"' -f4)
  fi
  if [ -n "$peerid" ]; then
    echo -e "${C_GREEN}✓ PeerID found!${C_RESET}"
    break
  fi
done

# ==== STEP 3: Display Results ====
if [ -n "$peerid" ]; then
  label=" ● PeerID"
  peerline="✓ $peerid"
  width=${#peerline}
  [ ${#label} -gt $width ] && width=${#label}
  line=$(printf '=%.0s' $(seq 1 $width))

  echo
  echo "$line"
  echo -e "$label"
  echo -e "${C_GREEN}$peerline${C_RESET}"
  echo -e "$line\n"

  echo -e "${C_BLUE}Fetching stats from Nethermind Aztec Explorer...${C_RESET}"
  API_URL="https://aztec.nethermind.io/api/peers?page_size=25&latest=true"
  response=$(curl --connect-timeout 5 --max-time 15 -s "$API_URL")

  if [ -z "$response" ] || ! echo "$response" | jq . > /dev/null 2>&1; then
      echo -e "${C_RED}❌ Failed to fetch data from the explorer or the API response was invalid.${C_RESET}"
      exit 1
  fi

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

    printf "%-12s: \033[36m%s\033[0m\n" "Last Seen"   "$last_local"
    printf "%-12s: \033[36m%s\033[0m\n" "First Seen"  "$first_local"
    printf "%-12s: \033[33m%s\033[0m\n" "Country"     "$country"
    printf "%-12s: \033[35m%s\033[0m\n" "Latitude"    "$lat"
    printf "%-12s: \033[35m%s\033[0m\n" "Longitude"   "$lon"
  else
    echo -e "${C_RED}No stats found for this PeerID on Nethermind Aztec Explorer.${C_RESET}"
    echo -e "${C_YELLOW}💡 Your node might have just started. Try again in a few minutes.${C_RESET}"
  fi
else
  echo -e "${C_RED}❌ No Aztec PeerID could be found in any container logs.${C_RESET}"
fi