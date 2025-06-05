#!/bin/bash

set -e

# Colors and box drawing
GREEN="\033[1;32m"
RESET="\033[0m"
TOP_LEFT="┌"
TOP_RIGHT="┐"
BOTTOM_LEFT="└"
BOTTOM_RIGHT="┘"
HORIZONTAL="─"
VERTICAL="│"

# Get block height
HEIGHT=$(wolodevd status 2>/dev/null | jq -r '.SyncInfo.latest_block_height')
# Get total supply
TOTAL_SUPPLY=$(wolodevd query bank total --output json | jq -r '.supply[] | select(.denom=="uwolo") | .amount')
# Dump account list to temp file
ACCOUNTS_JSON=$(mktemp)
wolodevd keys list --keyring-backend test --output json > "$ACCOUNTS_JSON"

# Prep rows
ROWS=()
ROWS+=("📦 Block Height: $HEIGHT")
ROWS+=("💰 Total Supply: $TOTAL_SUPPLY uwolo")
ROWS+=("")

cat "$ACCOUNTS_JSON" | jq -r '.[] | "\(.name)\t\(.address)"' | while IFS=$'\t' read -r name address; do
  balance=$(wolodevd query bank balances "$address" --output json | jq -r '.balances[]? | "\(.amount) \(.denom)"')
  ROWS+=("🧑 $name: $balance")
done

# Clean up
rm "$ACCOUNTS_JSON"

# Calculate max width
MAX_WIDTH=0
for row in "${ROWS[@]}"; do
  [ ${#row} -gt $MAX_WIDTH ] && MAX_WIDTH=${#row}
done
((MAX_WIDTH+=4))

# Draw top border
printf "${GREEN}${TOP_LEFT}"
for ((i=0; i<MAX_WIDTH; i++)); do printf "${HORIZONTAL}"; done
printf "${TOP_RIGHT}\n"

# Draw content
for row in "${ROWS[@]}"; do
  printf "${VERTICAL} ${row}"
  spaces=$((MAX_WIDTH - ${#row} - 1))
  for ((i=0; i<spaces; i++)); do printf " "; done
  printf "${VERTICAL}\n"
done

# Draw bottom border
printf "${BOTTOM_LEFT}"
for ((i=0; i<MAX_WIDTH; i++)); do printf "${HORIZONTAL}"; done
printf "${BOTTOM_RIGHT}${RESET}\n"
