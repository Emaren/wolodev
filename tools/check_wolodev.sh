#!/bin/bash

echo "=== 🚀 Wolodev Chain & ExplorerDev Health Check ==="
echo

# 1. wolodevd process
echo -n "[1] wolodevd process: "
pgrep -f "wolodevd start" >/dev/null && echo "✅ Running" || echo "❌ Not Running"

# 2. RPC (26657)
echo -n "[2] RPC (26657): "
if STATUS=$(curl -s http://localhost:26657/status); then
  HEIGHT=$(echo "$STATUS" | jq -r .result.sync_info.latest_block_height)
  TIME=$(echo "$STATUS" | jq -r .result.sync_info.latest_block_time)
  CATCHING_UP=$(echo "$STATUS" | jq -r .result.sync_info.catching_up)
  NETWORK=$(echo "$STATUS" | jq -r .result.node_info.network)
  echo "✅ OK (height: $HEIGHT, time: $TIME, catching_up: $CATCHING_UP, network: $NETWORK)"
else
  echo "❌ FAIL"
fi

# 3. REST API (1317)
echo -n "[3] REST API (1317): "
if BONDED=$(curl -s http://localhost:1317/cosmos/staking/v1beta1/pool | jq -r .pool.bonded_tokens 2>/dev/null); then
  echo "✅ OK (bonded_tokens: $BONDED)"
else
  echo "❌ FAIL"
fi

# 4. Validators (local)
echo -n "[4] Validators (local): "
VAL_COUNT=$(curl -s http://localhost:1317/cosmos/staking/v1beta1/validators | jq -r '.validators | length')
[[ "$VAL_COUNT" -gt 0 ]] && echo "✅ Found $VAL_COUNT validators" || echo "❌ None found"

# 5. Peer count
echo -n "[5] Peer count: "
PEERS=$(curl -s http://localhost:26657/net_info | jq -r .result.n_peers)
[[ "$PEERS" =~ ^[0-9]+$ ]] && echo "✅ $PEERS peers connected" || echo "❌ FAIL"

# 6. NGINX service
echo -n "[6] NGINX service: "
systemctl is-active nginx >/dev/null && echo "✅ Running" || echo "❌ Not Running"

# 7. Public REST (explorer)
echo -n "[7] Public REST (explorer): "
PBONDED=$(curl -s https://explorer.aoe2hdbets.com/cosmos/staking/v1beta1/pool)
echo "$PBONDED" | jq -r .pool.bonded_tokens >/dev/null 2>&1 && echo "✅ OK" || echo "❌ FAIL"

# 8. Public RPC (explorer)
echo -n "[8] Public RPC (explorer): "
PSTATUS=$(curl -s https://explorer.aoe2hdbets.com/tendermint/status)
echo "$PSTATUS" | jq -r .result.sync_info.latest_block_height >/dev/null 2>&1 && echo "✅ OK" || echo "❌ FAIL"

# 9. Explorer Web UI
echo -n "[9] Explorer Web UI: "
curl -s -o /dev/null -w "%{http_code}" https://explorer.aoe2hdbets.com | grep -q "200" && echo "✅ OK" || echo "❌ FAIL"

# 10. chain_id in wolodev.json
echo -n "[10] chain_id in wolodev.json: "
CHAIN_ID=$(curl -s https://explorer.aoe2hdbets.com/chains/mainnet/wolodev.json | jq -r .chain_id)
if [[ "$CHAIN_ID" == "wolodev" ]]; then
  echo "✅ Found (chain_id: $CHAIN_ID)"
elif [[ "$CHAIN_ID" == "null" || -z "$CHAIN_ID" ]]; then
  echo "❌ Missing"
else
  echo "❌ Incorrect (found: $CHAIN_ID)"
fi

# 11. Public RPC (node)
echo -n "[11] Public RPC (node): "
NHEIGHT=$(curl -s https://node.aoe2hdbets.com:26657/status | jq -r .result.sync_info.latest_block_height 2>/dev/null)
[[ -n "$NHEIGHT" ]] && echo "✅ OK (height: $NHEIGHT)" || echo "❌ FAIL"

# 12. Public REST (node)
echo -n "[12] Public REST (node): "
NBONDED=$(curl -s https://node.aoe2hdbets.com:1317/cosmos/staking/v1beta1/pool | jq -r .pool.bonded_tokens 2>/dev/null)
[[ -n "$NBONDED" ]] && echo "✅ OK (bonded_tokens: $NBONDED)" || echo "❌ FAIL"

# 13. Logo file
echo -n "[13] Logo file (/logos/wolo-logo-14.svg): "
LOGO_PATH="/var/www/explorerdev/dist/logos/wolo-logo-4.svg"
[[ -f "$LOGO_PATH" ]] && echo "✅ Present" || echo "❌ Missing (checked: $LOGO_PATH)"

echo -e "💡 If you updated logo or wolodev.json, run: pm2 restart frontend or systemctl reload nginx"

# 14. Public bonded (explorer)
echo -n "[14] Public bonded (explorer): "
curl -s https://explorer.aoe2hdbets.com/cosmos/staking/v1beta1/pool | jq -r .pool.bonded_tokens 2>/dev/null || echo "❌"

# 15. Public bonded (node)
echo -n "[15] Public bonded (node): "
PBOND_NODE=$(curl -s https://node.aoe2hdbets.com:1317/cosmos/staking/v1beta1/pool | jq -r .pool.bonded_tokens 2>/dev/null)
echo "${PBOND_NODE:-❌}"

echo -e "\n=== 🔍 Extended Supply Endpoint Diagnostics ==="

# 16. Local /supply/uwolo
echo -n "[16] Local /supply/uwolo: "
curl -s http://localhost:1317/cosmos/bank/v1beta1/supply/uwolo | jq -r .amount 2>/dev/null || echo "❌ FAIL"

# 17. Local /denoms_metadata
echo -n "[17] Local /denoms_metadata: "
curl -s http://localhost:1317/cosmos/bank/v1beta1/denoms_metadata | jq -r '.metadatas[] | select(.base=="uwolo") | .display' 2>/dev/null || echo "❌ FAIL"

# 18. Public /supply/uwolo (explorer)
echo -n "[18] Public /supply/uwolo (explorer): "
curl -sk https://explorer.aoe2hdbets.com/cosmos/bank/v1beta1/supply/uwolo | jq -r .amount 2>/dev/null || echo "❌ FAIL"

# 19. Ping.pub backend route
echo -n "[19] Ping.pub backend route: "
curl -sk https://explorer.aoe2hdbets.com/backend/cosmos/cosmos/bank/v1beta1/supply/uwolo | grep -q "Not Implemented" && echo "❌ 501 Not Implemented" || echo "✅ OK or Other"

# 20. Chain JSON denom display
echo -n "[20] Chain JSON denom alias: "
jq -r '.denom_units[]? | select(.denom=="uwolo") | .aliases[]?' /var/www/explorerdev/public/chains/mainnet/wolodev.json 2>/dev/null || echo "❌ Missing alias"

# 21. Response headers (backend route)
echo -n "[21] Response headers (backend): "
status=$(curl -sk -o /dev/null -w "%{http_code}" https://explorer.aoe2hdbets.com/backend/cosmos/cosmos/bank/v1beta1/supply/uwolo)
[[ "$status" == "501" ]] && echo "❌ 501 Not Implemented" || echo "✅ $status"

# 22. REST port 1317 listening
echo -n "[22] REST Port 1317: "
ss -tuln | grep -q ":1317 " && echo "✅ Listening" || echo "❌ Not Listening"

# 23. NGINX proxy config (/backend)
echo -n "[23] NGINX proxy for /backend/: "
grep -Ri "location /backend" /etc/nginx /var/www/explorerdev 2>/dev/null | head -n 1 || echo "❌ Not found"

# 24. app.go route registration
echo -n "[24] app.go RegisterQueryHandlerServer: "
grep -q "RegisterQueryHandlerServer" /var/www/wolodev/app/app.go && echo "✅ Found" || echo "❌ Missing"

echo "=== 🧩 Supply Endpoint Debug Complete ==="
