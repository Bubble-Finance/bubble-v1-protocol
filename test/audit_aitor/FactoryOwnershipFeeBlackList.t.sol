// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: BubbleV1Factory
// ----------------------------------

// ----------------------------------
//    Foundry Contracts Imports
// ----------------------------------

import { Test, console } from "lib/forge-std/src/Test.sol";

// --------------------------------
//    Bubble Contracts Imports
// --------------------------------

import { ERC20 } from "lib/solmate/src/tokens/ERC20.sol";

import { Deployer } from "test/baseHelpers/Deployer.sol";

import { BubbleV1Library } from "src/library/BubbleV1Library.sol";
import { BubbleV1Types } from "src/library/BubbleV1Types.sol";

// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------

contract FactoryOwnershipFeeBlackList is Test, Deployer {
    // ----------------------------------
    //   Variables and Constants
    // ----------------------------------
    uint256 constant WBTC_10K = 10_000 * 1e18;
    uint256 constant WETH_50K = 50_000e18;
    uint256 constant WETH_100K = 10_000e18;
    uint256 constant USDT_100K = 10_0000 * 1e6;
    uint256 constant USDT_500K = 500_000 * 1e6;
    uint256 constant DAI_50K = 50_000 * 1e18;
    uint256 constant DAI_500K = 50_0000 * 1e18;

    // ----------------------------------
    //   Modifiers()
    // ----------------------------------
    modifier setTimelockerAsOwner() {
        vm.prank(protocolTeamMultisig);
        s_factory.transferOwnership(address(s_timelock));
        _;
    }

    modifier deployNewPool() {
        vm.startPrank(LP1);
        address poolWETHDAI = s_factory.deployPool(address(wETH), address(DAI));
        vm.stopPrank();
        _;
    }

    // ----------------------------------
    //    setBlackListedToken()
    // ----------------------------------

    // @audit-check I have to try to add tokens in the pool function
    function testFail_TryToAddLiqToPoolWithBlacklistedToken() public {
        // ** POOL CREATED BEFORE BLACKLISTED **
        vm.prank(LP1);
        s_factory.deployPool(address(wBTC), address(DAI));
        vm.prank(protocolTeamMultisig);
        s_factory.setBlackListedToken(address(DAI), true);
        vm.startPrank(LP1);
        wBTC.approve(address(s_router), WBTC_10K);
        DAI.approve(address(s_router), DAI_50K);

        BubbleV1Types.AddLiquidity memory liquidityLP1 = BubbleV1Types.AddLiquidity({
            tokenA: address(wBTC),
            tokenB: address(DAI),
            amountADesired: WBTC_10K,
            amountBDesired: DAI_50K,
            amountAMin: 1,
            amountBMin: 1,
            receiver: LP1,
            deadline: block.timestamp
        });

        s_router.addLiquidity(liquidityLP1);
        vm.stopPrank();
    }

    function test_RemoveTokenFromBlacklist() public {
        // ** BLACKLIST TOKEN **
        vm.prank(protocolTeamMultisig);
        s_factory.setBlackListedToken(address(DAI), true);
        vm.expectRevert();
        vm.prank(LP1);
        s_factory.deployPool(address(wBTC), address(DAI));
        // ** REMOVE TOKEN FROM BLAKLIST
        vm.prank(protocolTeamMultisig);
        s_factory.setBlackListedToken(address(DAI), false);
        vm.prank(LP1);
        s_factory.deployPool(address(wBTC), address(DAI));
    }

    // ----------------------------------
    //    lockPool() and withdraw()
    // ----------------------------------
    function test_lockPoolByProtocolmultisig() public {
        vm.prank(LP1);
        address poolWETHDAI = s_factory.deployPool(address(wETH), address(DAI));
        vm.prank(protocolTeamMultisig);
        s_factory.lockPool(poolWETHDAI);
    }

    // ----------------------------------
    //    unLockPool() and withdraw()
    // ----------------------------------
    function test_unLockPoolByProtocolmultisig() public {
        vm.prank(LP1);
        address poolWETHDAI = s_factory.deployPool(address(wETH), address(DAI));
        vm.startPrank(protocolTeamMultisig);
        s_factory.lockPool(poolWETHDAI);
        s_factory.unlockPool(poolWETHDAI);
    }
}
