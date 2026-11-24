# DoraHacks BUIDL submission — Aevum Builder Challenge #1
URL: https://dorahacks.io/hackathon/qday  (submit before 2026-12-11 08:00 UTC = 16:00 SGT)

**Demo video:** https://w1nter625.github.io/truepay-aevum/video.html (player page) · direct MP4: https://github.com/w1nter625/truepay-aevum/releases/download/v1.0/truepay-demo.mp4 (2:28, English narration + burned-in captions)

---
## Ready-to-paste BUIDL fields

### BUIDL name
TruePay

### Logo
`assets/logo.png` in this repo (480×480 PNG) — https://raw.githubusercontent.com/w1nter625/truepay-aevum/main/assets/logo.png

### Tagline (≤100 chars)
Stablecoin invoices with bank-style Confirmation of Payee and on-chain anti-fraud spend controls.

### Short description
TruePay brings bank-style Confirmation of Payee to stablecoin invoices on QDay Aevum: payers see a match / close-match / no-match badge before paying, and the contract refuses to pay if the invoice's payee or amount was swapped.

### Track
Confirmation of Payee (secondary: Invoice Payments)

### Tags
Payments, Stablecoin, Anti-Fraud, Confirmation of Payee, Invoices, Solidity, QDay, Aevum, EIP-2612

### GitHub
https://github.com/w1nter625/truepay-aevum

### Demo URL
https://w1nter625.github.io/truepay-aevum/

### Video link
https://w1nter625.github.io/truepay-aevum/video.html

### Contract addresses (Aevum testnet, chain 44005, source-verified on Blockscout)
- PayeeRegistry: `0xC0994410270686F41c5401AEaF8abc7fd9a77d0c` — https://explorer-test.qday.info/address/0xC0994410270686F41c5401AEaF8abc7fd9a77d0c
- InvoiceBook: `0x5dA0203c562d46b6dA6e891c1B87da3E729F8E60` — https://explorer-test.qday.info/address/0x5dA0203c562d46b6dA6e891c1B87da3E729F8E60
- Payment token: tUSD8 `0x456569838f1d43009A91ebA4263147Afd7233483`
- Transaction proof (register, verify, invoice, pay, blocked swaps, refund): https://github.com/w1nter625/truepay-aevum/blob/main/demo-txs.md

### Team
Wynnter (solo)

### Full description (markdown)
```markdown
## The problem
Invoice fraud is simple: a scammer edits the bank details on a real invoice, or sends a look-alike invoice from a look-alike name. Banks in the UK/EU answer this with **Confirmation of Payee**: before you pay, the bank tells you "name matches / close match / no match". Stablecoin payments have no such check. You paste an address and hope.

## What TruePay does
1. **PayeeRegistry**: a merchant binds a handle (`@lim-bakery`) and a display / legal name to its payout address. An attestor (a KYB provider, or the platform) can add a **verified** badge. Changing the name **removes** the badge, so a hijacked account cannot keep a trusted name.
2. **Confirmation of Payee check**: `confirm(payee, expectedName)` returns match / registered-under-a-different-name / not registered. The web app shows a green / amber / red badge and only unlocks Pay on a match.
3. **InvoiceBook**: tUSD8 invoices with expiry, optional fixed payer, cancel and a 30-day merchant refund.
4. **On-chain safety checks at pay time**: the payer submits the *payee address and amount they confirmed*. If the invoice was swapped or edited, `pay` reverts with `PayeeMismatch` / `AmountMismatch` instead of paying the wrong party. Invoices can require a verified payee.
5. **Payer daily spending cap** per token (opt-in), enforced on-chain, which limits damage from a phished session or a compromised hot wallet.
6. **One-signature payment**: `payWithPermit` uses tUSD8's EIP-2612 permit.

## Built on Aevum
- Both contracts are deployed and source-verified on Aevum testnet; every flow in the demo is a real testnet transaction (see `demo-txs.md`).
- Static web app (viem, no build step) on GitHub Pages: merchant flow (register, create invoice) and payer flow (look up, confirm payee, pay).
- 9 Foundry tests: CoP results, swapped payee, amount tampering, verified-only, daily cap, expiry, cancel, refund, permit.

## Aevum compatibility note for other builders
Aevum's node accepts `PUSH0` but rejects `MCOPY` / `TSTORE`. Recent OpenZeppelin (5.4+) emits `mcopy`, so contracts built with it fail to deploy. TruePay pins **OpenZeppelin 5.0.2 + solc 0.8.24 + evm_version = shanghai**.

## What's next
Fuzzy "close match" scoring off-chain, multiple attestors, batch invoices, and payee-name lookups for wallets and payment links.

Built during the build window (Nov 24 – Dec 11). AI coding assistants were used.
```
