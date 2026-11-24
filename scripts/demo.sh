#!/usr/bin/env bash
# End-to-end demo on Aevum testnet, produces tx hashes for the submission (written to demo-txs.md).
# Needs two funded test wallets: merchant (PK_MERCHANT_FILE) and payer (PK_PAYER_FILE, holding tUSD8 + tQDAY).
# The deployer wallet is the registry attestor; by default it is the merchant wallet.
set -euo pipefail
export PATH=$HOME/.foundry/bin:$PATH
cd "$(dirname "$0")/.."
source deployed.env
R=https://rpc-test.qday.info; T=0x456569838f1d43009A91ebA4263147Afd7233483; X=https://explorer-test.qday.info/tx
PKM=$(cat "${PK_MERCHANT_FILE:?}"); PKP=$(cat "${PK_PAYER_FILE:?}")
M=$(cast wallet address "$PKM"); P=$(cast wallet address "$PKP")
out=demo-txs.md; echo "# TruePay demo transactions (Aevum testnet)" > $out
tx(){ local label=$1; shift; local h; h=$(cast send --legacy --rpc-url $R --json "$@" | jq -r .transactionHash); echo "- $label: $X/$h" | tee -a $out; }
tx "Merchant registers payee @lim-bakery" $REGISTRY "register(string,string)" lim-bakery "Lim Bakery Pte Ltd" --private-key "$PKM" || true
tx "Attestor verifies payee" $REGISTRY "setVerified(address,bool)" $M true --private-key "$PKM"
tx "Merchant creates invoice #N for 2.50 tUSD8 (verified payee required)" $BOOK "createInvoice(address,uint128,address,uint64,bool,string)" $T 2500000 0x0000000000000000000000000000000000000000 604800 true "INV-2026-0001 | 2 kaya toast sets" --private-key "$PKM"
ID=$(( $(cast call $BOOK "nextId()(uint256)" --rpc-url $R) - 1 ))
echo "- Invoice id: $ID" | tee -a $out
echo "- CoP check confirm(merchant,'lim bakery pte ltd') = $(cast call $REGISTRY 'confirm(address,string)(uint8)' $M 'lim bakery pte ltd' --rpc-url $R) (2 = match)" | tee -a $out
tx "Payer sets daily cap 10 tUSD8" $BOOK "setDailyCap(address,uint128)" $T 10000000 --private-key "$PKP"
tx "Payer approves 2.50 tUSD8" $T "approve(address,uint256)" $BOOK 2500000 --private-key "$PKP"
echo "- Swapped-payee attempt (expected revert PayeeMismatch):" | tee -a $out
cast call $BOOK "pay(uint256,address,uint128)" $ID $P 2500000 --from $P --rpc-url $R 2>&1 | tail -1 | sed 's/^/  /' | tee -a $out || true
tx "Payer pays invoice with confirmed payee+amount" $BOOK "pay(uint256,address,uint128)" $ID $M 2500000 --private-key "$PKP"
echo "- Remaining cap today: $(cast call $BOOK 'remainingToday(address,address)(uint256)' $P $T --rpc-url $R)" | tee -a $out
