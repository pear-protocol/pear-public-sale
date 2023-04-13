// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Script.sol";

import "../src/PublicSale.sol";
import {Address} from "../src/Addresses.sol";

contract PublishScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        address arb1_usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
        address pearFireblocks = 0xeDF7a5BC543874b81DEeCa16BCbF8FA43E03BD7a;
        // deploy PublicSale contract
        PublicSale publicSale = new PublicSale(arb1_usdc, pearFireblocks);
        console.log(address(publicSale));

        vm.stopBroadcast();
    }
}
