// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {PayeeRegistry} from "../src/PayeeRegistry.sol";
import {InvoiceBook} from "../src/InvoiceBook.sol";

/// forge script script/Deploy.s.sol --rpc-url aevum --broadcast --private-key $PK --legacy
contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        PayeeRegistry reg = new PayeeRegistry(msg.sender);
        InvoiceBook book = new InvoiceBook(reg);
        vm.stopBroadcast();
        console.log("PayeeRegistry", address(reg));
        console.log("InvoiceBook", address(book));
    }
}
