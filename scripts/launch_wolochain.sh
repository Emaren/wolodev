#!/usr/bin/env bash
set -e

APP=./build/wolochaind
CHAIN_ID="wolo"
CHAIN_HOME="$HOME/.wolodev"
DEPLOY_DIR="./deploy"

echo -e "\n🧨 Killing all running wolochaind processes..."
pkill -9 wolochaind || true

echo "🧨 Nuking old chain home @ $CHAIN_HOME..."
rm -rf "$CHAIN_HOME"

echo -e "\n🔫 Killing any stale processes on ports 26657, 6060, 1317, 9090..."
sudo lsof -ti :26657 | xargs -r sudo kill -9 || true
sudo lsof -ti :6060  | xargs -r sudo kill -9 || true
sudo lsof -ti :1317  | xargs -r sudo kill -9 || true
sudo lsof -ti :9090  | xargs -r sudo kill -9 || true

echo -e "\n🌱 Initializing fresh chain..."
$APP init stronghold --chain-id $CHAIN_ID --home $CHAIN_HOME --overwrite

echo -e "\n📥 Waiting for config directory to exist..."
while [ ! -d "$CHAIN_HOME/config" ]; do sleep 0.5; done

cp "$CHAIN_HOME/config/genesis.json" genesis.fresh.json

echo -e "\n🛑 Fresh genesis copied to genesis.fresh.json."
echo -e "✏️  Edit genesis.custom.json if needed or cp genesis.fresh.json genesis.custom.json"
echo -e "⏳ Press ENTER to continue..."
read -r

if [ -f genesis.custom.json ]; then
  echo -e "\n📥 Injecting patched genesis.custom.json..."
  cp genesis.custom.json "$CHAIN_HOME/config/genesis.json"
else
  echo -e "\n⚠️  No genesis.custom.json found. Launching with unmodified genesis."
fi

echo -e "\n🔎 Validating genesis..."
$APP validate-genesis --home $CHAIN_HOME

echo -e "\n🔑 Creating and confirming key: validator"
$APP keys add validator --keyring-backend test --home $CHAIN_HOME || true
VALIDATOR_ADDR=$($APP keys show validator -a --keyring-backend test --home $CHAIN_HOME)
if [ -z "$VALIDATOR_ADDR" ]; then
  echo -e "❌ ERROR: validator key not found. Aborting."
  exit 1
else
  echo -e "✅ Validator address: $VALIDATOR_ADDR"
fi

for acct in emperor faucet; do
  $APP keys add $acct --keyring-backend test --home $CHAIN_HOME || true
done

echo -e "\n📬 Key addresses:"
$APP keys list --home $CHAIN_HOME --keyring-backend test

echo -e "\n💰 Funding accounts..."
$APP add-genesis-account emperor   994000000000000uwolo --keyring-backend test --home $CHAIN_HOME
$APP add-genesis-account faucet     2000000000000uwolo   --keyring-backend test --home $CHAIN_HOME
$APP add-genesis-account validator  7000000000000uwolo   --keyring-backend test --home $CHAIN_HOME

echo -e "\n🧼 Nuking any old gentxs..."
rm -rf "$CHAIN_HOME/config/gentx"/*

echo -e "\n🗳️ Generating new gentx..."
$APP gentx validator 2000000000000uwolo \
  --from validator \
  --chain-id $CHAIN_ID \
  --moniker "stronghold" \
  --commission-rate "0.10" \
  --commission-max-rate "0.20" \
  --commission-max-change-rate "0.01" \
  --min-self-delegation "1" \
  --keyring-backend test \
  --home $CHAIN_HOME

echo -e "\n📄 Confirm gentx file created:"
ls -lh "$CHAIN_HOME/config/gentx/"

if [ ! -f "$CHAIN_HOME/config/gentx/"*.json ]; then
  echo -e "\n❌ ERROR: gentx file not found. Aborting."
  exit 1
fi

echo -e "\n🧾 gentx preview:"
cat "$CHAIN_HOME/config/gentx/"*.json | jq

echo -e "\n📦 Collecting gentxs..."
$APP collect-gentxs --home $CHAIN_HOME

echo -e "\n🧪 Checking if validator made it into genesis..."
VALIDATOR_COUNT=$(jq '.app_state.staking.validators | length' "$CHAIN_HOME/config/genesis.json")
if [ "$VALIDATOR_COUNT" -eq 0 ]; then
  echo -e "\n❌ ERROR: No validator in genesis.json. Aborting launch."
  exit 1
else
  echo -e "\n✅ $VALIDATOR_COUNT validator(s) found in genesis."
fi

echo -e "\n✅ Final genesis validation..."
$APP validate-genesis --home $CHAIN_HOME

echo -e "\n📦 Exporting wallet keys to $DEPLOY_DIR/keys/"
mkdir -p "$DEPLOY_DIR/keys"
for acct in validator emperor faucet; do
  $APP keys export $acct --keyring-backend test --home $CHAIN_HOME > "$DEPLOY_DIR/keys/${acct}.json"
done

echo -e "\n📦 Copying genesis.json and addrbook.json to $DEPLOY_DIR/"
cp "$CHAIN_HOME/config/genesis.json" "$DEPLOY_DIR/genesis.json"
cp "$CHAIN_HOME/config/addrbook.json" "$DEPLOY_DIR/addrbook.json" || true

echo -e "\n🚀 Launching node via PM2 as 'wolodev'..."
pm2 delete wolodev || true
pm2 start $APP --name wolodev -- \
  start \
  --home $CHAIN_HOME \
  --grpc.enable=true \
  --grpc.address="127.0.0.1:9090" \
  --api.enable=true \
  --api.address="tcp://0.0.0.0:1317"

echo -e "\n✅ Wolochaind is now running under PM2. Tail logs below:\n"
sleep 1
pm2 logs wolodev
