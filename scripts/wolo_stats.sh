#!/bin/bash
export LC_NUMERIC="en_US.UTF-8"

echo -e "\n🚀 WOLODEV CHAIN STATS\n========================="

echo -e "\n📦 Total Supply:"
curl -s http://localhost:1317/cosmos/bank/v1beta1/supply/uwolo \
  | jq -r '.amount.amount' \
  | awk '{ printf("💰 %'\''d WOLO\n", $1 / 1000000) }'

echo -e "\n🧱 Validators:"
curl -s http://localhost:1317/cosmos/staking/v1beta1/validators \
  | jq -r '.validators[] | [.description.moniker, (.tokens | tonumber)] | @tsv' \
  | while IFS=$'\t' read -r name tokens; do
      printf "🔹 %-12s: %'15d WOLO staked\n" "$name" "$((tokens / 1000000))"
    done

echo -e "\n🔑 On-Chain Accounts + Balances:"
curl -s http://localhost:1317/cosmos/bank/v1beta1/balances?pagination.limit=1000 \
  | jq -r '.balances[]? | [.address, .coins[]?.amount, .coins[]?.denom] | @tsv' \
  | while IFS=$'\t' read -r addr amt denom; do
      printf "🔐 %s\n   💸 %'15d %s\n" "$addr" "$((amt / 1000000))" "$denom"
    done

echo -e "\n🔑 Local Keys + Balances:"

KEYS_JSON=$(wolochaind keys list --home ~/.wolodev --keyring-backend test --output json 2>/dev/null | grep '^\[')

echo "$KEYS_JSON" \
  | jq -r '.[] | [.name, .address] | @tsv' \
  | while IFS=$'\t' read -r name addr; do
      printf "\n🔐 %-12s (%s)\n" "$name" "$addr"

      BAL=$(wolochaind query bank balances "$addr" --home ~/.wolodev --output json 2>/dev/null | grep '^{')

      echo "$BAL" \
        | jq -r '.balances[]? | select(.amount|test("^[0-9]+$")) | "\(.amount)\t\(.denom)"' \
        | while IFS=$'\t' read -r amt denom; do
            printf "   💸 %'15d %s\n" "$((amt / 1000000))" "$denom"
          done
    done

echo -e "\n🕒 Chain Status:"
curl -s http://localhost:26657/status | jq '.result.sync_info | {latest_block_height, latest_block_time, catching_up}'

echo -e "\n✅ Ping Test (supply):"
curl -s http://localhost:1317/cosmos/bank/v1beta1/supply | jq

