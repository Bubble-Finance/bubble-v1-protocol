// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: BubbleV1Factory
//  FUNCTIONS TESTED: 6
//  This test check all the sets and side features.
// ----------------------------------

// ----------------------------------
//  TEST:
//  1. renounceOwnership()
//  2. transferOwnership()
//  @audit-note Consider a 2 factor transferOwnership.=> we will transfer to a contract so it is not posible.
//  *** dev team reported that it is not possible as it will be transfer to a contract.
//  3. setProtocolTeamMultisig()
//  @audit-note Consider also 2 factor transfer ProtocolTeamMultisig => we will transfer to a contract so it is not posible.
//  4. setProtocolFee()
//  5. setTokenPairFee()
//  6. setBlackListedToken()
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
    //    Ownership and Access Control
    // ----------------------------------

    function test_renounceOwnership() external {
        vm.prank(protocolTeamMultisig);
        s_factory.renounceOwnership();
        assertEq(address(0), s_factory.owner());
    }

    function testFail_usersrCanNotransferOwnership() external {
        vm.prank(blackHat);
        s_factory.transferOwnership(blackHat);
    }

    function test_ownerCanTransferOwnership() external {
        vm.prank(protocolTeamMultisig);
        s_factory.transferOwnership(address(s_timelock));
        assertEq(address(s_timelock), s_factory.owner());
    }

    function testFail_notPossibleTransferToAddress0() external {
        vm.prank(protocolTeamMultisig);
        s_factory.transferOwnership(address(0));
    }

    function testFail_SetProtocolTeamMultisigToAddress0() external {
        vm.prank(protocolTeamMultisig);
        s_factory.setProtocolTeamMultisig(address(0));
        /* address newProtocolTeamMultisig = s_factory.getProtocolTeamMultisig();
        assertEq(newProtocolTeamMultisig, address(0)); */
    }

    function test_setNewProtocolTeamMultisig() external {
        vm.startPrank(protocolTeamMultisig);
        s_factory.setProtocolTeamMultisig(protocolTeamMultisig2);
        address newProtocolTeamMultisig = s_factory.getProtocolTeamMultisig();
        assertEq(protocolTeamMultisig2, newProtocolTeamMultisig);
        vm.stopPrank();
    }

    function testFail_usersCanNotSetProtocolTeamMultisig() external {
        vm.startPrank(blackHat);
        s_factory.setProtocolTeamMultisig(blackHat);
        vm.stopPrank();
    }

    // ----------------------------------
    //    setProtocolFee()
    // ----------------------------------
    function test_protocolTeamMultisigSetProtocolFees() external {
        vm.startPrank(protocolTeamMultisig);
        s_factory.setProtocolFee(BubbleV1Types.Fraction({ numerator: 3, denominator: 5 }));
        BubbleV1Types.Fraction memory newFees = s_factory.getProtocolFee();
        assertEq(newFees.numerator, 3);
        assertEq(newFees.denominator, 5);
    }

    function testFail_usersCanNotSetProtocolFees() external {
        vm.prank(blackHat);
        s_factory.setProtocolFee(BubbleV1Types.Fraction({ numerator: 1, denominator: 1000 }));
    }

    function testFail_ownerCanNotSetProtocolFees() external {
        vm.prank(protocolTeamMultisig);
        s_factory.transferOwnership(address(blackHat));
        vm.prank(blackHat);
        s_factory.setProtocolFee(BubbleV1Types.Fraction({ numerator: 1, denominator: 1000 }));
    }

    // ----------------------------------
    //    setTokenPairFee()
    // ----------------------------------
    function testFail_usersCanNotSetTokenPairFee() external deployNewPool {
        vm.startPrank(blackHat);
        s_factory.setTokenPairFee(address(wETH), address(DAI), 4);
        vm.stopPrank();
    }

    function testFail_revertIfTryToSetTokenPairFeeNotBetween1and5() external deployNewPool {
        vm.prank(protocolTeamMultisig);
        s_factory.setTokenPairFee(address(wETH), address(DAI), 8);
    }

    function test_setTokenPairFeeNotBetween1and5() external deployNewPool {
        vm.prank(protocolTeamMultisig);
        s_factory.setTokenPairFee(address(wETH), address(DAI), 4);
        BubbleV1Types.Fraction memory feeTier =
            s_factory.getTokenPairToFee(address(wETH), address(DAI));
        assertEq(feeTier.numerator, 4);
        assertEq(feeTier.denominator, 1000);
    }

    function test_ownerTimeLockerCanSetTokenPairFee() external deployNewPool setTimelockerAsOwner {
        vm.prank(address(s_timelock));
        s_factory.setTokenPairFee(address(wETH), address(DAI), 1);
        BubbleV1Types.Fraction memory feeTier =
            s_factory.getTokenPairToFee(address(wETH), address(DAI));
        assertEq(feeTier.numerator, 1);
        assertEq(feeTier.denominator, 1000);
    }

    function test_ifSortTokensWorksWithSetTokenPairFee() external deployNewPool {
        vm.startPrank(protocolTeamMultisig);
        s_factory.setTokenPairFee(address(wETH), address(DAI), 4);
        s_factory.setTokenPairFee(address(DAI), address(wETH), 3);
        BubbleV1Types.Fraction memory feeTier =
            s_factory.getTokenPairToFee(address(wETH), address(DAI));
        assertEq(feeTier.numerator, 3);
        assertEq(feeTier.denominator, 1000);
    }

    function test_setTokenPairFeeWithNotDeployedPool() external {
        address nonExistanPool = s_factory.getTokenPairToPool(address(wETH), address(DAI));
        assertEq(nonExistanPool, address(0));
        vm.prank(protocolTeamMultisig);
        s_factory.setTokenPairFee(address(wETH), address(DAI), 4);
    }

    // ----------------------------------
    //    setBlackListedToken()
    // ----------------------------------
    function testFail_TryToCreatePoolWithBlacklistedToken() public {
        vm.prank(protocolTeamMultisig);
        s_factory.setBlackListedToken(address(DAI), true);
        vm.prank(LP1);
        s_factory.deployPool(address(wBTC), address(DAI));
    }

    function testFail_TryToAddLiqToPoolWithBlacklistedToken() public {
        // ** POOL CREATED BEFORE BLACKLISTED **
        vm.prank(LP1);
        address poolwBTCDAI = s_factory.deployPool(address(wBTC), address(DAI));
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

        (uint256 amountALP1, uint256 amountBLP1, uint256 lpTokensMintedLP1) =
            s_router.addLiquidity(liquidityLP1);
        vm.stopPrank();
    }

    function testFail_OnlyMultisigCanBlacklistTokens() public {
        vm.prank(blackHat);
        s_factory.setBlackListedToken(address(DAI), true);
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
    //    lockPool()
    // ----------------------------------
    function test_lockPoolByProtocolmultisig() public {
        vm.prank(LP1);
        address poolWETHDAI = s_factory.deployPool(address(wETH), address(DAI));
        vm.prank(protocolTeamMultisig);
        s_factory.lockPool(poolWETHDAI);
    }

    // ----------------------------------
    //    unLockPool()
    // ----------------------------------
    function test_unLockPoolByProtocolmultisig() public {
        vm.prank(LP1);
        address poolWETHDAI = s_factory.deployPool(address(wETH), address(DAI));
        vm.startPrank(protocolTeamMultisig);
        s_factory.lockPool(poolWETHDAI);
        s_factory.unlockPool(poolWETHDAI);
    }
}
