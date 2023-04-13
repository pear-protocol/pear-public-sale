// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../src/PublicSale.sol";
import "../src/Addresses.sol";

contract CounterTest is Test {
    address arbUsdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address pearFireblocks = 0xeDF7a5BC543874b81DEeCa16BCbF8FA43E03BD7a;

    address alice = address(0xa); // deployer
    address bob = address(0xb); // treasury MPC
    address charlie = address(0xc); // user

    PublicSale public ps;

    function setUp() public {
        vm.prank(alice);
        ps = new PublicSale(arbUsdc, bob);
    }

    function testInit() public {
        assertEq(ps.owner(), bob); // owner is treasury MPC
        assertEq(ps.totalTokensSold(), 0); // no tokens sold yet
        assertEq(ps.saleEndEpoch(), 1682337600); // sale ends on 24th April 2023
        assertGt(ps.saleEndEpoch(), block.timestamp); // sale is still ongoing
        assertEq(ps.pricePerToken(), 25 * 1e3); // price per token is 0.025 USDC
        assertEq(ps.tokensForSale(), 100_000_000 * 1e18); // 100 million tokens for sale
        assertEq(address(ps.usdcToken()), arbUsdc); // USDC token address is correct
        assertEq(ps.tokenBalances(charlie), 0); // no tokens bought by charlie
        assertEq(IERC20(arbUsdc).balanceOf(address(ps)), 0); // no USDC in contract
    }

    function testPricePreview() public {
        // Price per token is 0.025 USDC.
        // 1 USDC buys 40 tokens.
        assertEq(ps.previewBuyTokens(1 * 1e6), 40 * 1e18); // 1 USDC buys 40 tokens
        assertEq(ps.previewBuyTokens(1_000 * 1e6), 40_000 * 1e18); // 1k USDC buys 40k tokens
        assertEq(ps.previewBuyTokens(1_000_000 * 1e6), 40_000_000 * 1e18); // 1m USDC buys 40m tokens
    }

    function test_RevertPausedBuy() public {
        uint256 amount = 1_000 * 1e6; // 1000 USDC
        deal(arbUsdc, charlie, amount);
        deal(charlie, 10000 ether);
        vm.startPrank(charlie);
        IERC20(arbUsdc).approve(address(ps), amount);
        vm.expectRevert(SaleIsPaused.selector);
        ps.buyTokens(amount);
        vm.stopPrank();

        assertEq(ps.totalTokensSold(), 0); // 0 tokens sold
        assertEq(ps.tokenBalances(charlie), 0); // 0 tokens bought by charlie
        assertEq(IERC20(arbUsdc).balanceOf(address(ps)), 0); // 0 USDC in contract
    }

    function testBuy() public {
        vm.prank(bob);
        ps.togglePause();
        uint256 amount = 1_000 * 1e6; // 1000 USDC
        deal(arbUsdc, charlie, amount);
        deal(charlie, 10000 ether);
        vm.startPrank(charlie);
        IERC20(arbUsdc).approve(address(ps), amount);
        ps.buyTokens(amount);
        vm.stopPrank();

        assertEq(ps.totalTokensSold(), 40_000 * 1e18); // 40k tokens sold
        assertEq(ps.tokenBalances(charlie), 40_000 * 1e18); // 40k tokens bought by charlie
        assertEq(IERC20(arbUsdc).balanceOf(address(ps)), amount); // 1000 USDC in contract
    }

    function testSecondUserBuy() public {
        testBuy(); // buy 40k tokens for charlie

        address dave = address(0xd); // second user
        uint256 amount = 2_000 * 1e6; // 2000 USDC
        deal(arbUsdc, dave, amount);
        deal(dave, 10000 ether);
        vm.startPrank(dave);
        IERC20(arbUsdc).approve(address(ps), amount);
        ps.buyTokens(amount);
        vm.stopPrank();

        assertEq(ps.totalTokensSold(), 120_000 * 1e18); // 80k tokens sold
        assertEq(ps.tokenBalances(dave), 80_000 * 1e18); // 40k tokens bought by dave
        assertEq(IERC20(arbUsdc).balanceOf(address(ps)), 3_000 * 1e6); // 3000 USDC in contract
    }

    function testRepeatBuy() public {
        testBuy(); // buy 40k tokens for charlie

        uint256 amount = 1_000 * 1e6; // 1000 USDC
        deal(arbUsdc, charlie, amount);
        deal(charlie, 10000 ether);
        vm.startPrank(charlie);
        IERC20(arbUsdc).approve(address(ps), amount);
        ps.buyTokens(amount);
        vm.stopPrank();

        assertEq(ps.totalTokensSold(), 80_000 * 1e18); // 80k tokens sold
        assertEq(ps.tokenBalances(charlie), 80_000 * 1e18); // 40k tokens bought by charlie
        assertEq(IERC20(arbUsdc).balanceOf(address(ps)), 2_000 * 1e6); // 2000 USDC in contract
    }

    function test_RevertBuyAboveMax() public {
        uint256 amount = 1_000_000_000 * 1e6; // 1 billion USDC
        deal(arbUsdc, charlie, amount);
        deal(charlie, 10000 ether);
        vm.startPrank(charlie);
        IERC20(arbUsdc).approve(address(ps), amount);
        // !!! Expect reverts
        vm.expectRevert();
        ps.buyTokens(amount);
        vm.stopPrank();

        assertEq(ps.totalTokensSold(), 0); // no tokens sold
    }

    function testAccess() public {
        testBuy(); // buy 40k tokens for charlie

        // Only owner can call these functions
        vm.startPrank(charlie);
        vm.expectRevert("Ownable: caller is not the owner");
        ps.withdrawUsdc();
        vm.stopPrank();

        vm.startPrank(charlie);
        vm.expectRevert("Ownable: caller is not the owner");
        ps.extendSale();
        vm.stopPrank();

        // Owner, during the sale
        vm.startPrank(bob);
        vm.expectRevert(SaleIsOngoing.selector);
        ps.withdrawUsdc();
        vm.stopPrank();

        vm.startPrank(bob);
        uint40 saleEndEpoch = ps.saleEndEpoch();
        ps.extendSale();
        vm.stopPrank();
        assertGt(ps.saleEndEpoch(), saleEndEpoch);

        // warp to after the sale
        vm.warp(ps.saleEndEpoch() + 1);

        // User, after the sale
        vm.startPrank(charlie);
        vm.expectRevert(SaleIsOver.selector);
        ps.buyTokens(1);
        vm.stopPrank();

        // owner, after the sale
        vm.startPrank(bob);
        ps.withdrawUsdc();
        vm.stopPrank();

        assertEq(IERC20(arbUsdc).balanceOf(address(ps)), 0); // no USDC in contract
        assertEq(IERC20(arbUsdc).balanceOf(bob), 1_000 * 1e6); // 1000 USDC in owner's wallet

        vm.startPrank(bob);
        vm.expectRevert(SaleIsOver.selector);
        ps.extendSale();
        vm.stopPrank();
    }
}
