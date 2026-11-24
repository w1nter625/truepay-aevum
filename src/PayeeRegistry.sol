// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title PayeeRegistry
/// @notice Confirmation of Payee (CoP) for on-chain payments. A merchant binds a
///         human-readable handle and legal/display name to its payout address.
///         An attestor (the registry owner, e.g. a KYB provider) can mark a payee
///         as verified. Payers check handle -> address -> name BEFORE they pay,
///         the way UK/EU banks show "name matches / close match / no match".
contract PayeeRegistry is Ownable {
    struct Payee {
        string handle;      // lowercase a-z0-9-_ , unique
        string displayName; // e.g. "Lim Bakery Pte Ltd"
        bool verified;      // set by attestor
        uint64 registeredAt;
        uint64 updatedAt;   // name/handle changes reset verification
    }

    mapping(address => Payee) private _payees;
    mapping(bytes32 => address) public ownerOfHandle;

    event PayeeRegistered(address indexed payee, string handle, string displayName);
    event PayeeUpdated(address indexed payee, string displayName);
    event PayeeVerified(address indexed payee, bool verified);

    error HandleTaken();
    error BadHandle();
    error NotRegistered();
    error AlreadyRegistered();

    constructor(address attestor) Ownable(attestor) {}

    function register(string calldata handle, string calldata displayName) external {
        if (_payees[msg.sender].registeredAt != 0) revert AlreadyRegistered();
        _checkHandle(handle);
        bytes32 h = keccak256(bytes(handle));
        if (ownerOfHandle[h] != address(0)) revert HandleTaken();
        ownerOfHandle[h] = msg.sender;
        _payees[msg.sender] = Payee(handle, displayName, false, uint64(block.timestamp), uint64(block.timestamp));
        emit PayeeRegistered(msg.sender, handle, displayName);
    }

    /// @notice Changing the display name drops the verified badge (anti-impersonation).
    function updateDisplayName(string calldata displayName) external {
        Payee storage p = _payees[msg.sender];
        if (p.registeredAt == 0) revert NotRegistered();
        p.displayName = displayName;
        p.updatedAt = uint64(block.timestamp);
        if (p.verified) {
            p.verified = false;
            emit PayeeVerified(msg.sender, false);
        }
        emit PayeeUpdated(msg.sender, displayName);
    }

    function setVerified(address payee, bool v) external onlyOwner {
        if (_payees[payee].registeredAt == 0) revert NotRegistered();
        _payees[payee].verified = v;
        emit PayeeVerified(payee, v);
    }

    function payeeOf(address a) external view returns (Payee memory) {
        return _payees[a];
    }

    function resolve(string calldata handle) external view returns (address payee, Payee memory info) {
        payee = ownerOfHandle[keccak256(bytes(handle))];
        info = _payees[payee];
    }

    /// @notice Returns 2 = exact name match, 1 = registered but name differs, 0 = not registered.
    function confirm(address payee, string calldata expectedName) external view returns (uint8) {
        Payee storage p = _payees[payee];
        if (p.registeredAt == 0) return 0;
        return keccak256(bytes(_lower(p.displayName))) == keccak256(bytes(_lower(expectedName))) ? 2 : 1;
    }

    function _checkHandle(string calldata handle) internal pure {
        bytes memory b = bytes(handle);
        if (b.length < 3 || b.length > 32) revert BadHandle();
        for (uint256 i; i < b.length; ++i) {
            bytes1 c = b[i];
            bool ok = (c >= 0x61 && c <= 0x7a) || (c >= 0x30 && c <= 0x39) || c == 0x2d || c == 0x5f;
            if (!ok) revert BadHandle();
        }
    }

    function _lower(string memory s) internal pure returns (string memory) {
        bytes memory b = bytes(s);
        for (uint256 i; i < b.length; ++i) {
            if (b[i] >= 0x41 && b[i] <= 0x5a) b[i] = bytes1(uint8(b[i]) + 32);
        }
        return string(b);
    }
}
