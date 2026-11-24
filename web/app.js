import { createPublicClient, createWalletClient, custom, http, parseUnits, formatUnits, isAddress, parseSignature } from "https://esm.sh/viem@2.21.0";
import { ABI } from "./abi.js";
import { CHAIN, TUSD8, REGISTRY, BOOK } from "./config.js";

const $ = (id) => document.getElementById(id);
const pub = createPublicClient({ chain: CHAIN, transport: http() });
let wallet, account, current;
const ERC20 = [
  { type: "function", name: "approve", stateMutability: "nonpayable", inputs: [{ name: "s", type: "address" }, { name: "v", type: "uint256" }], outputs: [{ type: "bool" }] },
  { type: "function", name: "balanceOf", stateMutability: "view", inputs: [{ name: "a", type: "address" }], outputs: [{ type: "uint256" }] },
  { type: "function", name: "nonces", stateMutability: "view", inputs: [{ name: "a", type: "address" }], outputs: [{ type: "uint256" }] },
  { type: "function", name: "name", stateMutability: "view", inputs: [], outputs: [{ type: "string" }] },
];
const log = (m) => { $("log").textContent = `[${new Date().toLocaleTimeString()}] ${m}\n` + $("log").textContent; };
const txLink = (h) => `${CHAIN.blockExplorers.default.url}/tx/${h}`;

async function send(req) {
  const hash = await wallet.writeContract({ ...req, account, chain: CHAIN });
  log(`sent ${req.functionName}: ${txLink(hash)}`);
  const r = await pub.waitForTransactionReceipt({ hash });
  log(`${req.functionName} ${r.status} in block ${r.blockNumber}`);
  return r;
}

$("connect").onclick = async () => {
  if (!window.ethereum) return log("No browser wallet found. Install MetaMask/Rabby.");
  try { await window.ethereum.request({ method: "wallet_switchEthereumChain", params: [{ chainId: "0xabe5" }] }); }
  catch { await window.ethereum.request({ method: "wallet_addEthereumChain", params: [{ chainId: "0xabe5", chainName: CHAIN.name, nativeCurrency: CHAIN.nativeCurrency, rpcUrls: CHAIN.rpcUrls.default.http, blockExplorerUrls: [CHAIN.blockExplorers.default.url] }] }); }
  wallet = createWalletClient({ chain: CHAIN, transport: custom(window.ethereum) });
  [account] = await wallet.requestAddresses();
  const bal = await pub.readContract({ address: TUSD8, abi: ERC20, functionName: "balanceOf", args: [account] });
  $("connect").textContent = `${account.slice(0, 6)}…${account.slice(-4)} · ${formatUnits(bal, 6)} tUSD8`;
  log(`connected ${account}`);
  refreshCap();
};

$("register").onclick = async () => {
  await send({ address: REGISTRY, abi: ABI.PayeeRegistry, functionName: "register", args: [$("handle").value.trim(), $("dname").value.trim()] });
};

$("create").onclick = async () => {
  const payer = $("payerOnly").value.trim();
  const r = await send({ address: BOOK, abi: ABI.InvoiceBook, functionName: "createInvoice",
    args: [TUSD8, parseUnits($("amt").value || "0", 6), isAddress(payer) ? payer : "0x0000000000000000000000000000000000000000", BigInt($("ttl").value), $("reqv").checked, $("memo").value] });
  const id = await pub.readContract({ address: BOOK, abi: ABI.InvoiceBook, functionName: "nextId" }) - 1n;
  const url = `${location.origin}${location.pathname}?invoice=${id}`;
  $("paylink").innerHTML = `Invoice #${id} created. Pay link: <a href="${url}">${url}</a>`;
};

async function check() {
  const id = BigInt($("invId").value || "0");
  const inv = await pub.readContract({ address: BOOK, abi: ABI.InvoiceBook, functionName: "getInvoice", args: [id] });
  const p = await pub.readContract({ address: REGISTRY, abi: ABI.PayeeRegistry, functionName: "payeeOf", args: [inv.payee] });
  const exp = $("expName").value.trim();
  const res = exp ? await pub.readContract({ address: REGISTRY, abi: ABI.PayeeRegistry, functionName: "confirm", args: [inv.payee, exp] }) : null;
  const status = ["None", "Open", "Paid", "Cancelled", "Refunded"][inv.status];
  const expired = Number(inv.expiresAt) * 1000 < Date.now();
  const match = res === 2 ? `<span class="badge ok">NAME MATCH</span>` : res === 1 ? `<span class="badge warn">NAME DIFFERS — registered as "${p.displayName}"</span>` : res === 0 ? `<span class="badge bad">PAYEE NOT REGISTERED</span>` : `<span class="badge warn">Type the name you expect to pay</span>`;
  $("cop").innerHTML = `
    <div><b>#${id}</b> · ${formatUnits(inv.amount, 6)} tUSD8 · status <b>${status}</b>${expired ? ' <span class="badge bad">EXPIRED</span>' : ""}</div>
    <div>Memo: ${inv.memo || "—"}</div>
    <div>Payee: <code>${inv.payee}</code></div>
    <div>Registered name: <b>${p.displayName || "—"}</b> (@${p.handle || "—"}) ${p.verified ? '<span class="badge ok">VERIFIED</span>' : '<span class="badge warn">UNVERIFIED</span>'}</div>
    <div style="margin-top:6px">${match}</div>
    <div class="mut">The pay button sends this exact payee + amount to the contract. If the invoice is swapped or edited, the payment reverts.</div>`;
  current = inv.status === 1 && !expired && res === 2 ? { id, inv } : null;
  $("pay").disabled = $("pay2").disabled = !current || !account;
}
$("check").onclick = check;

async function refreshCap() {
  if (!account) return;
  const rem = await pub.readContract({ address: BOOK, abi: ABI.InvoiceBook, functionName: "remainingToday", args: [account, TUSD8] });
  $("capinfo").textContent = rem > 10n ** 30n ? "No daily cap set." : `Remaining today: ${formatUnits(rem, 6)} tUSD8`;
}
$("setcap").onclick = async () => { await send({ address: BOOK, abi: ABI.InvoiceBook, functionName: "setDailyCap", args: [TUSD8, parseUnits($("cap").value || "0", 6)] }); refreshCap(); };

$("pay").onclick = async () => {
  const { id, inv } = current;
  const nonce = await pub.readContract({ address: TUSD8, abi: ERC20, functionName: "nonces", args: [account] });
  const name = await pub.readContract({ address: TUSD8, abi: ERC20, functionName: "name" });
  const deadline = BigInt(Math.floor(Date.now() / 1000) + 1800);
  const sig = await wallet.signTypedData({ account, domain: { name, version: "2", chainId: CHAIN.id, verifyingContract: TUSD8 },
    types: { Permit: [{ name: "owner", type: "address" }, { name: "spender", type: "address" }, { name: "value", type: "uint256" }, { name: "nonce", type: "uint256" }, { name: "deadline", type: "uint256" }] },
    primaryType: "Permit", message: { owner: account, spender: BOOK, value: inv.amount, nonce, deadline } });
  const { v, r, s } = parseSignature(sig);
  await send({ address: BOOK, abi: ABI.InvoiceBook, functionName: "payWithPermit", args: [id, inv.payee, inv.amount, deadline, Number(v), r, s] });
  check(); refreshCap();
};
$("pay2").onclick = async () => {
  const { id, inv } = current;
  await send({ address: TUSD8, abi: ERC20, functionName: "approve", args: [BOOK, inv.amount] });
  await send({ address: BOOK, abi: ABI.InvoiceBook, functionName: "pay", args: [id, inv.payee, inv.amount] });
  check(); refreshCap();
};

const q = new URLSearchParams(location.search).get("invoice");
if (q) { $("invId").value = q; check(); }
