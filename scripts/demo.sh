#!/usr/bin/env bash
# End-to-end demo on QDay Aevum testnet. Writes every tx link to demo-txs.md.
# Needs two funded test wallets: merchant (PK_MERCHANT_FILE, also registry attestor = deployer)
# and payer (PK_PAYER_FILE, holding tUSD8 + tQDAY). Never commit the key files.
set -euo pipefail
export PATH=$HOME/.foundry/bin:$PATH
cd "$(dirname "$0")/.."
source deployed.env
R=https://rpc-test.qday.info; T=0x456569838f1d43009A91ebA4263147Afd7233483; X=https://explorer-test.qday.info
PKM=$(cat "${PK_MERCHANT_FILE:?}"); PKP=$(cat "${PK_PAYER_FILE:?}")
M=$(cast wallet address --private-key "$PKM"); P=$(cast wallet address --private-key "$PKP")
Z=0x0000000000000000000000000000000000000000
out=demo-txs.md
{ echo "# TruePay demo transactions (QDay Aevum testnet, chain 44005)"; echo; echo "Generated $(date -u +%Y-%m-%dT%H:%MZ) by scripts/demo.sh"; echo;
  echo "- PayeeRegistry: [$REGISTRY]($X/address/$REGISTRY)"; echo "- InvoiceBook: [$BOOK]($X/address/$BOOK)";
  echo "- Merchant (payee + attestor): [$M]($X/address/$M)"; echo "- Payer: [$P]($X/address/$P)"; echo "- Token: tUSD8 [$T]($X/address/$T)"; echo; } > $out
tx(){ local label=$1; shift; local h="" i
  for i in 1 2 3 4; do h=$(cast send --legacy --rpc-url $R --json "$@" 2>/tmp/demo-err.txt | jq -r .transactionHash) && [ -n "$h" ] && [ "$h" != null ] && break; echo "  retry $i: $(head -c 200 /tmp/demo-err.txt)" >&2; sleep 4; done
  [ -n "$h" ] && [ "$h" != null ] || { echo "FAILED: $label" >&2; exit 1; }
  echo "- $label: [$h]($X/tx/$h)" | tee -a $out; sleep 2; }
rev(){ local label=$1; shift; local sel name; sel=$(cast call --rpc-url $R "$@" 2>&1 | grep -oE 'data: "0x[0-9a-f]{8}' | grep -oE '0x[0-9a-f]{8}' | head -1 || true)
  case "$sel" in 0xe28e12ad) name=PayeeMismatch;; 0x55e97b0d) name=AmountMismatch;; 0xddafad98) name=NotOpen;; *) name="${sel:-reverted}";; esac
  echo "- $label → reverts with \`$name()\` (simulated with eth_call, no tx sent)" | tee -a $out; }
last_id(){ echo $(( $(cast call $BOOK "nextId()(uint256)" --rpc-url $R) - 1 )); }

echo "## 1. Merchant onboarding" | tee -a $out
if [ "$(cast call $REGISTRY 'confirm(address,string)(uint8)' $M 'x' --rpc-url $R)" = "0" ]; then
  tx "Merchant registers payee @lim-bakery = \"Lim Bakery Pte Ltd\"" $REGISTRY "register(string,string)" lim-bakery "Lim Bakery Pte Ltd" --private-key "$PKM"
fi
tx "Attestor marks @lim-bakery as VERIFIED" $REGISTRY "setVerified(address,bool)" $M true --private-key "$PKM"

echo; echo "## 2. Invoice + Confirmation of Payee" | tee -a $out
tx "Merchant creates invoice: 2.50 tUSD8, 7 days, verified payee required" $BOOK "createInvoice(address,uint128,address,uint64,bool,string)" $T 2500000 $Z 604800 true "INV-2026-0001 | 2 kaya toast sets" --private-key "$PKM"
ID=$(last_id); echo "- Invoice id: **$ID**" | tee -a $out
echo "- CoP check \`confirm(payee, \"lim bakery pte ltd\")\` = $(cast call $REGISTRY 'confirm(address,string)(uint8)' $M 'lim bakery pte ltd' --rpc-url $R) (2 = NAME MATCH)" | tee -a $out
echo "- CoP check \`confirm(payee, \"Lim Bakery\")\` = $(cast call $REGISTRY 'confirm(address,string)(uint8)' $M 'Lim Bakery' --rpc-url $R) (1 = name differs → warn)" | tee -a $out
echo "- CoP check \`confirm(payer address, \"Lim Bakery Pte Ltd\")\` = $(cast call $REGISTRY 'confirm(address,string)(uint8)' $P 'Lim Bakery Pte Ltd' --rpc-url $R) (0 = not registered → block)" | tee -a $out

echo; echo "## 3. Payer safety controls" | tee -a $out
tx "Payer sets a daily cap of 3 tUSD8" $BOOK "setDailyCap(address,uint128)" $T 3000000 --private-key "$PKP"
tx "Payer approves 2.50 tUSD8 to InvoiceBook" $T "approve(address,uint256)" $BOOK 2500000 --private-key "$PKP"
rev "Tampered payee (pay to a swapped address)" $BOOK "pay(uint256,address,uint128)" $ID $P 2500000 --from $P
rev "Tampered amount (25.00 instead of 2.50)" $BOOK "pay(uint256,address,uint128)" $ID $M 25000000 --from $P
tx "Payer pays invoice #$ID with the confirmed payee + amount" $BOOK "pay(uint256,address,uint128)" $ID $M 2500000 --private-key "$PKP"
echo "- Remaining daily cap: $(cast call $BOOK 'remainingToday(address,address)(uint256)' $P $T --rpc-url $R) (atomic, 6 decimals)" | tee -a $out
rev "Paying the same invoice twice" $BOOK "pay(uint256,address,uint128)" $ID $M 2500000 --from $P

echo; echo "## 4. Refund and cancel" | tee -a $out
tx "Merchant approves refund amount" $T "approve(address,uint256)" $BOOK 2500000 --private-key "$PKM"
tx "Merchant refunds invoice #$ID to the payer (30-day window)" $BOOK "refund(uint256)" $ID --private-key "$PKM"
tx "Merchant creates invoice for 1.00 tUSD8" $BOOK "createInvoice(address,uint128,address,uint64,bool,string)" $T 1000000 $Z 86400 false "INV-2026-0002 | wrong order" --private-key "$PKM"
ID2=$(last_id)
tx "Merchant cancels unpaid invoice #$ID2" $BOOK "cancel(uint256)" $ID2 --private-key "$PKM"
rev "Paying a cancelled invoice" $BOOK "pay(uint256,address,uint128)" $ID2 $M 1000000 --from $P

echo; echo "## 5. Open invoice left for the web UI demo" | tee -a $out
tx "Merchant creates invoice for 1.20 tUSD8 (open, for the UI)" $BOOK "createInvoice(address,uint128,address,uint64,bool,string)" $T 1200000 $Z 2592000 true "INV-2026-0003 | teh tarik x3" --private-key "$PKM"
echo "- Open invoice id: **$(last_id)**" | tee -a $out
echo "- Payer tUSD8 balance after demo: $(cast call $T 'balanceOf(address)(uint256)' $P --rpc-url $R)" | tee -a $out
