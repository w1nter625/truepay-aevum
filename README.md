# TruePay — stablecoin invoices with Confirmation of Payee (QDay Aevum)

**Track:** Confirmation of Payee (also fits Invoice Payments) · **Network:** QDay Aevum Testnet (chain 44005) · **Token:** tUSD8

## The problem
Invoice fraud is simple: a scammer edits the bank details on a real invoice, or sends a look-alike
invoice from a look-alike name. Banks in the UK/EU answer this with *Confirmation of Payee* — before
you pay, the bank tells you "name matches / close match / no match". Stablecoin payments have no such
check: you paste an address and hope.

## What TruePay does
1. **PayeeRegistry** — a merchant binds a handle (`@lim-bakery`) and a display / legal name to its
   payout address. An attestor (a KYB provider, or the platform) can add a **verified** badge.
   Changing the name **removes** the badge, so a hijacked account cannot keep a trusted name.
2. **Confirmation of Payee check** — `confirm(payee, expectedName)` returns `2` (match), `1`
   (registered under a different name) or `0` (not registered). The web app shows this as a
   green / amber / red badge, and only enables the Pay button on a match.
3. **InvoiceBook** — invoices in tUSD8 with expiry, optional fixed payer, cancel and a 30-day merchant refund.
4. **On-chain safety checks at pay time** — the payer sends the *payee address and amount they
   confirmed*. If the invoice was swapped or edited, `pay` reverts with `PayeeMismatch` /
   `AmountMismatch` instead of paying the wrong party. Invoices can require a verified payee.
5. **Payer daily spending cap** per token (opt-in), enforced on-chain — limits damage from a
   phished session or a compromised hot wallet.
6. **One-signature payment** — `payWithPermit` uses tUSD8's EIP-2612 permit (domain version `"2"`).

## Architecture
```
 Merchant ──register/createInvoice──▶ PayeeRegistry ◀──confirm()── Payer UI (web/)
                                   ╲        ▲                          │
                                    ▼       │ payeeOf()                │ payWithPermit(id, payee, amount)
                                 InvoiceBook ─────────────────────────┘
                                    │ safeTransferFrom(payer → payee)
                                    ▼
                                  tUSD8 (0x4565…3483)
```
* `src/PayeeRegistry.sol`, `src/InvoiceBook.sol` — Solidity 0.8.24, OpenZeppelin 5.0.2.
* `web/` — static single-page app (viem), no build step. Merchant and payer flows.
* `scripts/deploy.sh`, `scripts/demo.sh` — deploy and a scripted end-to-end demo that writes tx hashes to `demo-txs.md`.

## Aevum compatibility note (useful for other builders)
Aevum's node (`cdk-erigon`) accepts `PUSH0` but rejects `MCOPY` and `TSTORE` (Cancun). The latest
OpenZeppelin (5.4+, `^0.8.31`) emits `mcopy`, so contracts built with it **fail to deploy**.
TruePay pins **OpenZeppelin v5.0.2 + solc 0.8.24 + `evm_version = "shanghai"`**.

## Run it
```bash
git submodule update --init --recursive   # forge-std + OpenZeppelin v5.0.2
forge test                      # 9 tests: CoP, swapped payee, amount tamper, verified-only, cap, expiry, cancel, refund, permit
PK_FILE=path/to/test_key ./scripts/deploy.sh      # deploys + writes web/config.js
PK_MERCHANT_FILE=... PK_PAYER_FILE=... ./scripts/demo.sh
cd web && python3 -m http.server 8080            # open http://localhost:8080
```
Test tokens: https://faucet.qday.info/en (tQDAY for gas, tUSD8).

## Deployed (Aevum Testnet, chain 44005) — source verified on Blockscout
* PayeeRegistry: [`0xC0994410270686F41c5401AEaF8abc7fd9a77d0c`](https://explorer-test.qday.info/address/0xC0994410270686F41c5401AEaF8abc7fd9a77d0c)
* InvoiceBook: [`0x5dA0203c562d46b6dA6e891c1B87da3E729F8E60`](https://explorer-test.qday.info/address/0x5dA0203c562d46b6dA6e891c1B87da3E729F8E60)
* Live web app: https://w1nter625.github.io/truepay-aevum/ (try invoice **#3**, expected name `Lim Bakery Pte Ltd`)
* Every demo transaction (register, verify, create, pay, refund, cancel, plus the simulated tamper reverts): [`demo-txs.md`](demo-txs.md)

## Safety, trust and controls
* Least privilege: the contract never holds funds (direct payer → payee transfer); no admin can move money.
* The only privileged role is the registry attestor, which can only toggle a badge.
* Spend caps, invoice expiry, payer restriction, explicit payee+amount confirmation, refund path.
* Re-entrancy guarded; SafeERC20.

## Roadmap
Fuzzy name matching off-chain ("close match"), ERC-8004 agent identities as payees, recurring invoices,
QR codes for in-shop payment, merchant webhooks.

License: MIT
