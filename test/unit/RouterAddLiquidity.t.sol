// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: MonadexV1Router
//  FUNCTIONS TESTED: 2
//  This test check all the get functions of the Router contract.
// ----------------------------------

// ----------------------------------
//  TEST:
//  1. addLiquidity()
//  @audit-low Small amount, 1000 (0,0...1), get trapped in address(1) as expected.
//  ********** No withdraw function but reported.
//  @audit-note Protocol does not accept tokenA = 0 but accept tokenA = 1 (0.0000..01)
//  *********** Check the influence in K and raffles
//  2. addLiquidityNative()
// ----------------------------------

// ----------------------------------
//    Foundry Contracts Imports
// ----------------------------------

import { Test, console } from "lib/forge-std/src/Test.sol";

// --------------------------------
//    Monadex Contracts Imports
// --------------------------------

import { ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import { Deployer } from "test/baseHelpers/Deployer.sol";

import { MonadexV1Library } from "src/library/MonadexV1Library.sol";
import { MonadexV1Types } from "src/library/MonadexV1Types.sol";

// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------

contract RouterAddLiquidity is Test, Deployer {
    // ** For tokens with 18 decimals **
    uint256 constant ADD_10K = 10000e18;
    uint256 constant ADD_50K = 50000e18;
    uint256 constant ADD_100K = 10000e18;
    uint256 constant ADD_500K = 500000e18;

    // ** For tokens with 6 decimals **
    uint256 constant USDT_10K = 10000e6;
    uint256 constant USDT_50K = 50000e6;
    uint256 constant USDT_100K = 100000e6;
    uint256 constant USDT_500K = 500000e6;

    // --------------------------------
    //    addLiquidity()
    // --------------------------------

    function test_initialSupplyAddDAI_WBTC() public {
        vm.startPrank(LP1);
        wBTC.approve(address(s_router), ADD_10K);
        DAI.approve(address(s_router), ADD_50K);

        // Note: deadline = max deadLine possible => 1921000304
        MonadexV1Types.AddLiquidity memory liquidityLP1 = MonadexV1Types.AddLiquidity({
            tokenA: address(wBTC),
            tokenB: address(DAI),
            amountADesired: ADD_10K,
            amountBDesired: ADD_50K,
            amountAMin: 1,
            amountBMin: 1,
            receiver: LP1,
            deadline: block.timestamp
        });
        (uint256 amountALP1, uint256 amountBLP1, uint256 lpTokensMintedLP1) =
            s_router.addLiquidity(liquidityLP1);
        vm.stopPrank();

        address poolAddress = s_factory.getTokenPairToPool(address(wBTC), address(DAI));

        /*
         * CHECKS:
         */
        assertEq(wBTC.balanceOf(poolAddress), ADD_10K);
        assertEq(DAI.balanceOf(poolAddress), ADD_50K);
        assert(ERC20(poolAddress).balanceOf(LP1) != 0);
        assertEq(ERC20(poolAddress).balanceOf(LP1), lpTokensMintedLP1);
        assertEq(ERC20(poolAddress).balanceOf(address(1)), 1000);
        assertEq(
            ERC20(poolAddress).balanceOf(LP1),
            ERC20(poolAddress).totalSupply() - ERC20(poolAddress).balanceOf(address(1))
        );
    }

    function test_secondSupplyAddDAI_WBTC() public {
        test_initialSupplyAddDAI_WBTC();
        address poolAddress = s_factory.getTokenPairToPool(address(wBTC), address(DAI));
        uint256 DAIBalance = DAI.balanceOf(poolAddress);
        uint256 wBTCBalance = wBTC.balanceOf(poolAddress);

        vm.startPrank(LP2);
        wBTC.approve(address(s_router), ADD_50K);
        DAI.approve(address(s_router), ADD_500K);

        // Note: deadline = max deadLine possible => 1921000304
        MonadexV1Types.AddLiquidity memory liquidityLP2 = MonadexV1Types.AddLiquidity({
            tokenA: address(DAI),
            tokenB: address(wBTC),
            amountADesired: ADD_500K,
            amountBDesired: ADD_50K,
            amountAMin: 1,
            amountBMin: 1,
            receiver: LP2,
            deadline: block.timestamp
        });
        (uint256 amountALP2, uint256 amountBLP2, uint256 lpTokensMintedLP2) =
            s_router.addLiquidity(liquidityLP2);
        vm.stopPrank();

        /*
         * CHECKS
         */
        assertEq(wBTC.balanceOf(poolAddress), wBTCBalance + ADD_50K);
        uint256 DAIUserBalance = DAI.balanceOf(LP2);
        assertEq(DAI.balanceOf(poolAddress) + DAIUserBalance - DAIBalance, 1e24);
        // @audit-note Protocol is not taking all the token approved.
        assert(ERC20(poolAddress).balanceOf(LP2) != 0);
        assertEq(ERC20(poolAddress).balanceOf(address(1)), 1000);
        assertEq(
            ERC20(poolAddress).balanceOf(LP1) + ERC20(poolAddress).balanceOf(LP2),
            ERC20(poolAddress).totalSupply() - ERC20(poolAddress).balanceOf(address(1))
        );
    }

    function testFail_addLiquidityAmountAEqualToZero() public {
        vm.startPrank(LP1);
        wBTC.approve(address(s_router), ADD_50K);
        DAI.approve(address(s_router), ADD_500K);

        MonadexV1Types.AddLiquidity memory liquidityLP1 = MonadexV1Types.AddLiquidity({
            tokenA: address(wBTC),
            tokenB: address(DAI),
            amountADesired: 0,
            amountBDesired: ADD_500K,
            amountAMin: 1,
            amountBMin: 1,
            receiver: LP1,
            deadline: block.timestamp
        });

        (uint256 amountALP1, uint256 amountBLP1, uint256 lpTokensMintedLP1) =
            s_router.addLiquidity(liquidityLP1);
        vm.stopPrank();

        address poolAddress = s_factory.getTokenPairToPool(address(wBTC), address(DAI));
        assertEq(wBTC.balanceOf(poolAddress), 0);
        assertEq(DAI.balanceOf(poolAddress), ADD_500K);
        assert(ERC20(poolAddress).balanceOf(LP1) != 0);
    }

    function test_addLiquidityAmountAEqualToOne() public {
        vm.startPrank(LP1);
        wBTC.approve(address(s_router), 1);
        DAI.approve(address(s_router), ADD_500K);

        MonadexV1Types.AddLiquidity memory liquidityLP1 = MonadexV1Types.AddLiquidity({
            tokenA: address(wBTC),
            tokenB: address(DAI),
            amountADesired: 1,
            amountBDesired: ADD_500K,
            amountAMin: 1,
            amountBMin: 1,
            receiver: LP1,
            deadline: block.timestamp
        });

        (uint256 amountALP1, uint256 amountBLP1, uint256 lpTokensMintedLP1) =
            s_router.addLiquidity(liquidityLP1);
        vm.stopPrank();

        address poolAddress = s_factory.getTokenPairToPool(address(wBTC), address(DAI));

        assertEq(wBTC.balanceOf(poolAddress), 1);
        assertEq(DAI.balanceOf(poolAddress), ADD_500K);
        assert(ERC20(poolAddress).balanceOf(LP1) != 0);
    }

    // --------------------------------
    //    addLiquidityNative()
    // --------------------------------

    function test_initialSupplyAddNative_DAI() public {
        vm.startPrank(LP2);
        DAI.approve(address(s_router), ADD_50K);

        MonadexV1Types.AddLiquidityNative memory nativeLP1 = MonadexV1Types.AddLiquidityNative({
            token: address(DAI),
            amountTokenDesired: ADD_50K,
            amountTokenMin: 1,
            amountNativeTokenMin: 1,
            receiver: LP1,
            deadline: block.timestamp
        });

        (uint256 amountTokenLP1, uint256 amountNativeLP1, uint256 lpTokensMintedLP1) =
            s_router.addLiquidityNative{ value: ADD_100K }(nativeLP1);
        vm.stopPrank();

        address poolAddress = s_factory.getTokenPairToPool(address(wMonad), address(DAI));

        /*
         * CHECKS
         */
        assertEq(wMonad.balanceOf(poolAddress), ADD_100K);
        assertEq(DAI.balanceOf(poolAddress), ADD_50K);
        assert(ERC20(poolAddress).balanceOf(LP1) != 0);
        assertEq(ERC20(poolAddress).balanceOf(LP1), lpTokensMintedLP1);
        assertEq(ERC20(poolAddress).balanceOf(address(1)), 1000);
        assertEq(
            ERC20(poolAddress).balanceOf(LP1),
            ERC20(poolAddress).totalSupply() - ERC20(poolAddress).balanceOf(address(1))
        );
    }

    function testFail_add_ZeroNative_50KDAI() public {
        vm.startPrank(LP2);
        DAI.approve(address(s_router), ADD_50K);

        MonadexV1Types.AddLiquidityNative memory nativeLP1 = MonadexV1Types.AddLiquidityNative({
            token: address(DAI),
            amountTokenDesired: ADD_50K,
            amountTokenMin: 1,
            amountNativeTokenMin: 1,
            receiver: LP1,
            deadline: block.timestamp
        });

        (uint256 amountTokenLP1, uint256 amountNativeLP1, uint256 lpTokensMintedLP1) =
            s_router.addLiquidityNative(nativeLP1);
        vm.stopPrank();
    }
}
