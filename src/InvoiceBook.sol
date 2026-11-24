// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {PayeeRegistry} from "./PayeeRegistry.sol";

/// @title InvoiceBook
/// @notice Stablecoin invoices with payer-side safety controls:
///  - Confirmation of Payee: payer must pass the payee address AND amount it saw;
///    a tampered / swapped invoice reverts instead of paying the wrong party.
///  - Payee must be registered in PayeeRegistry (optionally must be verified).
///  - Per-payer daily spend cap per token (opt-in), enforced on-chain.
///  - Invoices expire; merchants can cancel unpaid ones and refund paid ones
///    within a refund window.
contract InvoiceBook is ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum Status { None, Open, Paid, Cancelled, Refunded }

    struct Invoice {
        address payee;
        address payer;      // address(0) = anyone may pay
        address token;
        uint128 amount;
        uint64 createdAt;
        uint64 expiresAt;
        uint64 paidAt;
        address paidBy;
        Status status;
        bool requireVerified;
        string memo;        // e.g. "INV-2026-0042 | 12 croissants"
    }

    struct SpendLimit { uint128 dailyCap; uint128 spentToday; uint64 day; }

    PayeeRegistry public immutable registry;
    uint64 public constant REFUND_WINDOW = 30 days;
    uint256 public nextId = 1;

    mapping(uint256 => Invoice) private _invoices;
    mapping(address => mapping(address => SpendLimit)) public spendLimits; // payer => token => limit

    event InvoiceCreated(uint256 indexed id, address indexed payee, address indexed payer, address token, uint256 amount, uint64 expiresAt, string memo);
    event InvoicePaid(uint256 indexed id, address indexed payer, address indexed payee, uint256 amount);
    event InvoiceCancelled(uint256 indexed id);
    event InvoiceRefunded(uint256 indexed id, address indexed to, uint256 amount);
    event SpendLimitSet(address indexed payer, address indexed token, uint256 dailyCap);

    error NotPayee();
    error PayeeNotRegistered();
    error PayeeNotVerified();
    error NotOpen();
    error Expired();
    error WrongPayer();
    error PayeeMismatch();
    error AmountMismatch();
    error OverDailyCap(uint256 remaining);
    error RefundWindowOver();
    error BadParams();

    constructor(PayeeRegistry _registry) { registry = _registry; }

    // ------------------------------------------------------------------ merchant
    function createInvoice(address token, uint128 amount, address payer, uint64 ttlSeconds, bool requireVerified, string calldata memo)
        external returns (uint256 id)
    {
        if (amount == 0 || token == address(0) || ttlSeconds == 0 || ttlSeconds > 365 days) revert BadParams();
        if (registry.payeeOf(msg.sender).registeredAt == 0) revert PayeeNotRegistered();
        id = nextId++;
        uint64 exp = uint64(block.timestamp) + ttlSeconds;
        _invoices[id] = Invoice(msg.sender, payer, token, amount, uint64(block.timestamp), exp, 0, address(0), Status.Open, requireVerified, memo);
        emit InvoiceCreated(id, msg.sender, payer, token, amount, exp, memo);
    }

    function cancel(uint256 id) external {
        Invoice storage inv = _invoices[id];
        if (inv.payee != msg.sender) revert NotPayee();
        if (inv.status != Status.Open) revert NotOpen();
        inv.status = Status.Cancelled;
        emit InvoiceCancelled(id);
    }

    /// @notice Merchant returns funds to the payer within REFUND_WINDOW.
    function refund(uint256 id) external nonReentrant {
        Invoice storage inv = _invoices[id];
        if (inv.payee != msg.sender) revert NotPayee();
        if (inv.status != Status.Paid) revert NotOpen();
        if (block.timestamp > inv.paidAt + REFUND_WINDOW) revert RefundWindowOver();
        inv.status = Status.Refunded;
        IERC20(inv.token).safeTransferFrom(msg.sender, inv.paidBy, inv.amount);
        emit InvoiceRefunded(id, inv.paidBy, inv.amount);
    }

    // --------------------------------------------------------------------- payer
    /// @notice Opt-in daily cap per token. 0 disables the cap.
    function setDailyCap(address token, uint128 cap) external {
        spendLimits[msg.sender][token].dailyCap = cap;
        emit SpendLimitSet(msg.sender, token, cap);
    }

    /// @param expectedPayee the address the payer confirmed via PayeeRegistry (CoP)
    /// @param expectedAmount the amount the payer saw on the invoice
    function pay(uint256 id, address expectedPayee, uint128 expectedAmount) public nonReentrant {
        Invoice storage inv = _invoices[id];
        _checkPayable(inv, expectedPayee, expectedAmount);
        _consumeCap(msg.sender, inv.token, inv.amount);
        inv.status = Status.Paid;
        inv.paidAt = uint64(block.timestamp);
        inv.paidBy = msg.sender;
        IERC20(inv.token).safeTransferFrom(msg.sender, inv.payee, inv.amount);
        emit InvoicePaid(id, msg.sender, inv.payee, inv.amount);
    }

    /// @notice One-transaction pay using EIP-2612 permit (tUSD8 supports permit).
    function payWithPermit(uint256 id, address expectedPayee, uint128 expectedAmount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
    {
        Invoice storage inv = _invoices[id];
        try IERC20Permit(inv.token).permit(msg.sender, address(this), inv.amount, deadline, v, r, s) {} catch {}
        pay(id, expectedPayee, expectedAmount);
    }

    // ---------------------------------------------------------------------- views
    function getInvoice(uint256 id) external view returns (Invoice memory) { return _invoices[id]; }

    function remainingToday(address payer, address token) external view returns (uint256) {
        SpendLimit memory l = spendLimits[payer][token];
        if (l.dailyCap == 0) return type(uint256).max;
        uint64 today = uint64(block.timestamp / 1 days);
        uint256 spent = l.day == today ? l.spentToday : 0;
        return l.dailyCap > spent ? l.dailyCap - spent : 0;
    }

    // ------------------------------------------------------------------ internal
    function _checkPayable(Invoice storage inv, address expectedPayee, uint128 expectedAmount) internal view {
        if (inv.status != Status.Open) revert NotOpen();
        if (block.timestamp > inv.expiresAt) revert Expired();
        if (inv.payer != address(0) && inv.payer != msg.sender) revert WrongPayer();
        if (inv.payee != expectedPayee) revert PayeeMismatch();
        if (inv.amount != expectedAmount) revert AmountMismatch();
        PayeeRegistry.Payee memory p = registry.payeeOf(inv.payee);
        if (p.registeredAt == 0) revert PayeeNotRegistered();
        if (inv.requireVerified && !p.verified) revert PayeeNotVerified();
    }

    function _consumeCap(address payer, address token, uint128 amount) internal {
        SpendLimit storage l = spendLimits[payer][token];
        if (l.dailyCap == 0) return;
        uint64 today = uint64(block.timestamp / 1 days);
        if (l.day != today) { l.day = today; l.spentToday = 0; }
        uint256 remaining = l.dailyCap > l.spentToday ? l.dailyCap - l.spentToday : 0;
        if (amount > remaining) revert OverDailyCap(remaining);
        l.spentToday += amount;
    }
}
