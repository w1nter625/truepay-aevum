#!/usr/bin/env bash
# Deploy TruePay to QDay Aevum Testnet. Needs a funded test wallet (tQDAY for gas from https://faucet.qday.info/en).
# Usage: PK_FILE=/home/box/secrets/aevum_test_pk ./scripts/deploy.sh
set -euo pipefail
export PATH=$HOME/.foundry/bin:$PATH
cd "$(dirname "$0")/.."
PK=$(cat "${PK_FILE:?set PK_FILE}")
forge script script/Deploy.s.sol --rpc-url https://rpc-test.qday.info --broadcast --private-key "$PK" --legacy --slow --start-fresh | tee deploy.log
REG=$(grep -oP 'PayeeRegistry \K0x[0-9a-fA-F]{40}' deploy.log)
BOOK=$(grep -oP 'InvoiceBook \K0x[0-9a-fA-F]{40}' deploy.log)
sed -i "s/export const REGISTRY = .*/export const REGISTRY = \"$REG\";/; s/export const BOOK = .*/export const BOOK = \"$BOOK\";/" web/config.js
echo "REGISTRY=$REG BOOK=$BOOK" > deployed.env
echo "Deployed. Updated web/config.js"
