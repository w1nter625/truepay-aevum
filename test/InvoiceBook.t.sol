// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {PayeeRegistry} from "../src/PayeeRegistry.sol";
import {InvoiceBook} from "../src/InvoiceBook.sol";

contract MockUSD is ERC20, ERC20Permit {
    constructor() ERC20("tUSD8", "tUSD8") ERC20Permit("tUSD8") {}
    function decimals() public pure override returns (uint8) { return 6; }
    function mint(address to, uint256 a) external { _mint(to, a); }
}

contract InvoiceBookTest is Test {
    MockUSD usd; PayeeRegistry reg; InvoiceBook book;
    address attestor = address(0xA11CE);
    address bakery = address(0xB0B);
    address scammer = address(0xBAD);
    uint256 payerKey = 0xC0FFEE; address payer;

    function setUp() public {
        payer = vm.addr(payerKey);
        usd = new MockUSD(); reg = new PayeeRegistry(attestor); book = new InvoiceBook(reg);
        usd.mint(payer, 1_000e6); usd.mint(bakery, 1_000e6);
        vm.prank(bakery); reg.register("lim-bakery", "Lim Bakery Pte Ltd");
        vm.prank(attestor); reg.setVerified(bakery, true);
        vm.prank(scammer); reg.register("lim-bakery-sg", "Lim Bakery");
    }

    function _invoice(uint128 amt, bool reqVerified) internal returns (uint256 id) {
        vm.prank(bakery); id = book.createInvoice(address(usd), amt, address(0), 7 days, reqVerified, "INV-1");
    }

    function test_confirmOfPayee() public view {
        assertEq(reg.confirm(bakery, "lim bakery pte ltd"), 2);
        assertEq(reg.confirm(scammer, "Lim Bakery Pte Ltd"), 1);
        assertEq(reg.confirm(address(0x1234), "x"), 0);
        (address a,) = reg.resolve("lim-bakery"); assertEq(a, bakery);
    }

    function test_payHappyPath() public {
        uint256 id = _invoice(25e6, true);
        vm.startPrank(payer); usd.approve(address(book), 25e6); book.pay(id, bakery, 25e6); vm.stopPrank();
        assertEq(usd.balanceOf(bakery), 1_025e6);
        assertEq(uint8(book.getInvoice(id).status), uint8(InvoiceBook.Status.Paid));
    }

    function test_revertsOnSwappedPayee() public {
        uint256 id = _invoice(25e6, false);
        vm.startPrank(payer); usd.approve(address(book), 25e6);
        vm.expectRevert(InvoiceBook.PayeeMismatch.selector); book.pay(id, scammer, 25e6);
        vm.expectRevert(InvoiceBook.AmountMismatch.selector); book.pay(id, bakery, 2500e6);
        vm.stopPrank();
    }

    function test_requireVerified() public {
        vm.prank(scammer); uint256 id = book.createInvoice(address(usd), 5e6, address(0), 1 days, true, "x");
        vm.startPrank(payer); usd.approve(address(book), 5e6);
        vm.expectRevert(InvoiceBook.PayeeNotVerified.selector); book.pay(id, scammer, 5e6);
        vm.stopPrank();
    }

    function test_nameChangeDropsVerification() public {
        vm.prank(bakery); reg.updateDisplayName("Totally Different Co");
        assertFalse(reg.payeeOf(bakery).verified);
    }

    function test_dailyCap() public {
        uint256 a = _invoice(30e6, false); uint256 b = _invoice(30e6, false);
        vm.startPrank(payer); book.setDailyCap(address(usd), 50e6); usd.approve(address(book), 60e6);
        book.pay(a, bakery, 30e6);
        vm.expectRevert(abi.encodeWithSelector(InvoiceBook.OverDailyCap.selector, 20e6)); book.pay(b, bakery, 30e6);
        vm.warp(block.timestamp + 1 days); book.pay(b, bakery, 30e6);
        vm.stopPrank();
    }

    function test_expiryCancelRefund() public {
        uint256 id = _invoice(10e6, false);
        vm.warp(block.timestamp + 8 days);
        vm.prank(payer); vm.expectRevert(InvoiceBook.Expired.selector); book.pay(id, bakery, 10e6);
        uint256 id2 = _invoice(10e6, false);
        vm.prank(bakery); book.cancel(id2);
        vm.prank(payer); vm.expectRevert(InvoiceBook.NotOpen.selector); book.pay(id2, bakery, 10e6);
        uint256 id3 = _invoice(10e6, false);
        vm.startPrank(payer); usd.approve(address(book), 10e6); book.pay(id3, bakery, 10e6); vm.stopPrank();
        vm.startPrank(bakery); usd.approve(address(book), 10e6); book.refund(id3); vm.stopPrank();
        assertEq(usd.balanceOf(payer), 1_000e6);
    }

    function test_payWithPermit() public {
        uint256 id = _invoice(12e6, true);
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            payer, address(book), uint256(12e6), usd.nonces(payer), deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", usd.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(payerKey, digest);
        vm.prank(payer); book.payWithPermit(id, bakery, 12e6, deadline, v, r, s);
        assertEq(usd.balanceOf(bakery), 1_012e6);
    }

    function test_restrictedPayer() public {
        vm.prank(bakery); uint256 id = book.createInvoice(address(usd), 1e6, address(0xD00D), 1 days, false, "x");
        vm.startPrank(payer); usd.approve(address(book), 1e6);
        vm.expectRevert(InvoiceBook.WrongPayer.selector); book.pay(id, bakery, 1e6); vm.stopPrank();
    }
}
