# TruePay demo transactions (QDay Aevum testnet, chain 44005)

Generated 2026-11-24T13:06Z by scripts/demo.sh

- PayeeRegistry: [0xC0994410270686F41c5401AEaF8abc7fd9a77d0c](https://explorer-test.qday.info/address/0xC0994410270686F41c5401AEaF8abc7fd9a77d0c)
- InvoiceBook: [0x5dA0203c562d46b6dA6e891c1B87da3E729F8E60](https://explorer-test.qday.info/address/0x5dA0203c562d46b6dA6e891c1B87da3E729F8E60)
- Merchant (payee + attestor): [0x2c0D9404105b62e50f9218713BF932022Aca2889](https://explorer-test.qday.info/address/0x2c0D9404105b62e50f9218713BF932022Aca2889)
- Payer: [0x2EFF10488150A0Cd84DE7053eD562a365Bb139f2](https://explorer-test.qday.info/address/0x2EFF10488150A0Cd84DE7053eD562a365Bb139f2)
- Token: tUSD8 [0x456569838f1d43009A91ebA4263147Afd7233483](https://explorer-test.qday.info/address/0x456569838f1d43009A91ebA4263147Afd7233483)

## 0. Setup (test tokens + deploy)
- Discord /faucet → payer received 1 tQDAY: [0xb5bf7a4b84ac9e2d1a00325145d7416548962e9b9483d75fbd87aae4ce99b99c](https://explorer-test.qday.info/tx/0xb5bf7a4b84ac9e2d1a00325145d7416548962e9b9483d75fbd87aae4ce99b99c)
- Discord /faucet → payer received 5 tUSD8: [0x7a434ff77e273972f5198dd7f62d910c6f174f1bdac8806ea3af7cf4740a0fa2](https://explorer-test.qday.info/tx/0x7a434ff77e273972f5198dd7f62d910c6f174f1bdac8806ea3af7cf4740a0fa2)
- Payer sends 0.3 tQDAY gas to merchant: [0x6fb06f60fedf2604edbeccf91a0489024e047222fc05bb1b5ac545d4c0fb3115](https://explorer-test.qday.info/tx/0x6fb06f60fedf2604edbeccf91a0489024e047222fc05bb1b5ac545d4c0fb3115)
- Deploy PayeeRegistry: [0xe6475faeedec5b8d59497e85c0dbd23f2b506ca59805b0911af382a01e459c61](https://explorer-test.qday.info/tx/0xe6475faeedec5b8d59497e85c0dbd23f2b506ca59805b0911af382a01e459c61)
- Deploy InvoiceBook: [0xd037e7cd17c6ce45872505f6f937b20dbaae7912012576e3926f123697669aab](https://explorer-test.qday.info/tx/0xd037e7cd17c6ce45872505f6f937b20dbaae7912012576e3926f123697669aab)

## 1. Merchant onboarding
- Merchant registers payee @lim-bakery = "Lim Bakery Pte Ltd": [0x7c1fb63aba9750eb09242a5236960703fd134772cc6ef3a5c69aab7747af3156](https://explorer-test.qday.info/tx/0x7c1fb63aba9750eb09242a5236960703fd134772cc6ef3a5c69aab7747af3156)
- Attestor marks @lim-bakery as VERIFIED: [0x2c5dff466ecbdfa9ce24c62c255ea1fd6fa80ba776f95b5fa665441393b77724](https://explorer-test.qday.info/tx/0x2c5dff466ecbdfa9ce24c62c255ea1fd6fa80ba776f95b5fa665441393b77724)
## 2. Invoice + Confirmation of Payee
- Merchant creates invoice: 2.50 tUSD8, 7 days, verified payee required: [0x292dadf5b38c1d383d1db24631a99c92a67d9c7a3ba65391f93ae825b8c58d6d](https://explorer-test.qday.info/tx/0x292dadf5b38c1d383d1db24631a99c92a67d9c7a3ba65391f93ae825b8c58d6d)
- Invoice id: **1**
- CoP check `confirm(payee, "lim bakery pte ltd")` = 2 (2 = NAME MATCH)
- CoP check `confirm(payee, "Lim Bakery")` = 1 (1 = name differs → warn)
- CoP check `confirm(payer address, "Lim Bakery Pte Ltd")` = 0 (0 = not registered → block)
## 3. Payer safety controls
- Payer sets a daily cap of 3 tUSD8: [0x90d7ccb061d65da15b50dc0c8aadc938a8e722c2504e9d3828656bb05a36ae04](https://explorer-test.qday.info/tx/0x90d7ccb061d65da15b50dc0c8aadc938a8e722c2504e9d3828656bb05a36ae04)
- Payer approves 2.50 tUSD8 to InvoiceBook: [0x33263d082f70d4f9159171bf4ef7be6ace23a8ab912fc0d64190f7a58964de48](https://explorer-test.qday.info/tx/0x33263d082f70d4f9159171bf4ef7be6ace23a8ab912fc0d64190f7a58964de48)
- Tampered payee (pay to a swapped address) → reverts with `PayeeMismatch()` (simulated with eth_call, no tx sent)
- Tampered amount (25.00 instead of 2.50) → reverts with `AmountMismatch()` (simulated with eth_call, no tx sent)
- Payer pays invoice #1 with the confirmed payee + amount: [0xc13d93edfaad7f93c65667ba562785764832d91b98cf82a76a035285a1c16e75](https://explorer-test.qday.info/tx/0xc13d93edfaad7f93c65667ba562785764832d91b98cf82a76a035285a1c16e75)
- Remaining daily cap after paying 2.50 of 3.00: 0.50 tUSD8
- Paying the same invoice twice → reverts with `NotOpen()` (simulated with eth_call, no tx sent)
## 4. Refund and cancel
- Merchant approves refund amount: [0xf31197658a915238fb1d2b40ad74f1059476db26935ae9ecf0495027552fe52a](https://explorer-test.qday.info/tx/0xf31197658a915238fb1d2b40ad74f1059476db26935ae9ecf0495027552fe52a)
- Merchant refunds invoice #1 to the payer (30-day window): [0x289eabc5f77f00cca86c4d61e35c32e03817518145392d5ac074073ff7396f4f](https://explorer-test.qday.info/tx/0x289eabc5f77f00cca86c4d61e35c32e03817518145392d5ac074073ff7396f4f)
- Merchant creates invoice for 1.00 tUSD8: [0x8bfe322a8066bde40ea22c5da645c50aa56c0715b85ee1883f4524e58ffc1f67](https://explorer-test.qday.info/tx/0x8bfe322a8066bde40ea22c5da645c50aa56c0715b85ee1883f4524e58ffc1f67)
- Merchant cancels unpaid invoice #2: [0x5c832f80c27324f279e505bdf1bad92c3bfa604532adb04db97cb7d59ffe1448](https://explorer-test.qday.info/tx/0x5c832f80c27324f279e505bdf1bad92c3bfa604532adb04db97cb7d59ffe1448)
- Paying a cancelled invoice → reverts with `NotOpen()` (simulated with eth_call, no tx sent)
## 5. Open invoice left for the web UI demo
- Merchant creates invoice for 1.20 tUSD8 (open, for the UI): [0x2e56033ceb5f45ea75d96835fe5e05246c42bd6a3eeb7e3aaa75b889f7252d23](https://explorer-test.qday.info/tx/0x2e56033ceb5f45ea75d96835fe5e05246c42bd6a3eeb7e3aaa75b889f7252d23)
- Open invoice id: **3**
- Payer tUSD8 balance after demo: 5.00 (paid 2.50, refunded 2.50)
