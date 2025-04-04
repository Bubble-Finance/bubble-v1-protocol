// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: BubbleV1Router
//  FUNCTIONS TESTED: 4
//  This test check all the remove Liquidity functions of the Router contract.
// ----------------------------------

// ----------------------------------
//  TEST:
//  1. removeLiquidityWithPermit()
//  2. removeLiquidityNativeWithPermit()
//  3. removeLiquidity()
//  4. removeLiquidityNative()
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

import { RouterAddLiquidity } from "test/unit/RouterAddLiquidity.t.sol";

// ------------------------------------------------------
//    Contract for testing and debugging
// -----------------------------------------------------

contract RouterRemoveLiquidity is Test, Deployer, RouterAddLiquidity {
    // ----------------------------------
    //    removeLiquidity()
    // ----------------------------------
    function test_userRemove_50percent_ofOwnLiq() public {
        test_secondSupplyAddDAI_WBTC();
        address poolAddress = s_factory.getTokenPairToPool(address(wBTC), address(DAI));
        uint256 lpTokensUserLP1 = ERC20(poolAddress).balanceOf(LP1);

        vm.startPrank(LP1);
        ERC20(poolAddress).approve(address(s_router), lpTokensUserLP1);
        s_router.removeLiquidity(
            address(wBTC),
            address(DAI),
            lpTokensUserLP1,
            ADD_10K / 2,
            ADD_50K / 2,
            LP1,
            block.timestamp
        );
        vm.stopPrank();
    }

    function test_userRemove_50percent_ofOwnLiq_V2() public {
        test_secondSupplyAddDAI_WBTC();
        address poolAddress = s_factory.getTokenPairToPool(address(wBTC), address(DAI));
        uint256 lpTokensUserLP1 = ERC20(poolAddress).balanceOf(LP1);

        vm.startPrank(LP1);
        ERC20(poolAddress).approve(address(s_router), lpTokensUserLP1);
        s_router.removeLiquidity(
            address(wBTC),
            address(DAI),
            lpTokensUserLP1 / 2,
            ADD_10K / 3,
            ADD_50K / 3,
            LP1,
            block.timestamp
        );
        vm.stopPrank();
    }

    // ----------------------------------
    //    removeLiquidityNative()
    // ----------------------------------

    function test_userRemove_50percent_ofOwnNative() public {
        test_initialSupplyAddNative_DAI();
        address poolAddress = s_factory.getTokenPairToPool(address(wMonad), address(DAI));
        uint256 lpTokensUserLP1 = ERC20(poolAddress).balanceOf(LP1);

        vm.startPrank(LP1);
        ERC20(poolAddress).approve(address(s_router), lpTokensUserLP1);
        s_router.removeLiquidityNative(
            address(DAI), lpTokensUserLP1, ADD_50K / 8, ADD_50K / 8, LP1, block.timestamp
        );
        vm.stopPrank();
    }

    // ----------------------------------
    //    removeLiquidityWithPermit()
    // ----------------------------------
    function test_removeLiquidityWithPermit() public { }

    // ----------------------------------
    //    removeLiquidityNativeWithPermit()
    // ----------------------------------
    function test_removeLiquidityNativeWithPermit() public { }
}
