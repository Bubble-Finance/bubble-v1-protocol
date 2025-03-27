// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: BubbleV1Router
//  FUNCTIONS TESTED: 6 (+2)
//  1. removeLiquidityNativeSupportingFeeOnTransferTokens()
//  2. removeLiquidityNativeWithPermitSupportingFeeOnTransferTokens()
//  3. swapExactTokensForTokensSupportingFeeOnTransferTokens()
//  4. swapExactNativeForTokensSupportingFeeOnTransferTokens()
//  5. swapExactTokensForNativeSupportingFeeOnTransferTokens()
//  PLUS:
//  6. addLiquidity() => FOT
//  7. removeLiquidity() => FOT
// ----------------------------------

// ----------------------------------
//  TEST:
// ----------------------------------

// ----------------------------------
//    Foundry Contracts Imports
// ----------------------------------

import { Test, console2 } from "lib/forge-std/src/Test.sol";

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

contract RouterFeeOnTransfer is Test, Deployer {
    // ** For tokens with 18 decimals **
    uint256 constant ADD_10K = 10000e18;
    uint256 constant ADD_50K = 50000e18;
    uint256 constant ADD_100K = 10000e18;
    uint256 constant ADD_500K = 500000e18;

    // ----------------------------------
    //    Swap DAI and FOT
    // ----------------------------------

    function test_createFOTPoolAndAddLiquidityFOTDAI() public {
        vm.startPrank(fot);
        DAI.approve(address(s_router), ADD_50K);
        s_fotToken.approve(address(s_router), ADD_50K);

        BubbleV1Types.AddLiquidity memory liquidityFot = BubbleV1Types.AddLiquidity({
            tokenA: address(DAI),
            tokenB: address(s_fotToken),
            amountADesired: ADD_50K,
            amountBDesired: ADD_50K,
            amountAMin: 1,
            amountBMin: 1,
            receiver: fot,
            deadline: block.timestamp
        });

        (uint256 amountA, uint256 amountB, uint256 lpTokensMinted) =
            s_router.addLiquidity(liquidityFot);
        vm.stopPrank();

        address poolAddress = s_factory.getTokenPairToPool(address(DAI), address(s_fotToken));
        console2.log("poolAddress: ", poolAddress);

        /*
         * CHECKS:
         */
        assertEq(DAI.balanceOf(poolAddress), ADD_50K);
        assertEq(s_fotToken.balanceOf(poolAddress), ADD_50K - 1500e18);
        assert(ERC20(poolAddress).balanceOf(fot) != 0);
        assertEq(ERC20(poolAddress).balanceOf(fot), lpTokensMinted);
        assertEq(ERC20(poolAddress).balanceOf(address(1)), 1000);
        assertEq(
            ERC20(poolAddress).balanceOf(fot),
            ERC20(poolAddress).totalSupply() - ERC20(poolAddress).balanceOf(address(1))
        );
    }

    function test_addLiquidityFOTDAI() public {
        test_createFOTPoolAndAddLiquidityFOTDAI();
        vm.startPrank(fot);
        DAI.approve(address(s_router), 14e18);
        s_fotToken.approve(address(s_router), 3e18);

        // balances before:
        address poolAddress = s_factory.getTokenPairToPool(address(DAI), address(s_fotToken));
        console2.log("poolAddress: ", poolAddress);

        uint256 poolBalanceBeforeDAI = DAI.balanceOf(poolAddress);
        uint256 poolBalanceBeforeFOT = s_fotToken.balanceOf(poolAddress);
        console2.log("poolBalanceBeforeDAI: ", poolBalanceBeforeDAI);
        console2.log("poolBalanceBeforeFOT: ", poolBalanceBeforeFOT);

        BubbleV1Types.AddLiquidity memory liquidityFot = BubbleV1Types.AddLiquidity({
            tokenA: address(s_fotToken),
            tokenB: address(DAI),
            amountADesired: 3e18,
            amountBDesired: 14e18,
            amountAMin: 1,
            amountBMin: 1,
            receiver: fot,
            deadline: block.timestamp
        });

        (uint256 amountA, uint256 amountB, uint256 lpTokensMinted) =
            s_router.addLiquidity(liquidityFot);
        vm.stopPrank();

        /*
         * CHECKS:
         */
        console2.log("poolBalanceDAI: ", DAI.balanceOf(poolAddress));
        console2.log("poolBalanceFOT: ", s_fotToken.balanceOf(poolAddress));
    }

    function test_removeLiquidityFOTDAI() public {
        test_createFOTPoolAndAddLiquidityFOTDAI();

        address poolAddress = s_factory.getTokenPairToPool(address(DAI), address(s_fotToken));
        uint256 lpTokensUserFot = ERC20(poolAddress).balanceOf(fot);

        console2.log("User Balance DAI 1: ", DAI.balanceOf(fot));
        console2.log("User Balance FOT 1: ", s_fotToken.balanceOf(fot));
        console2.log("User Balance LP  1: ", lpTokensUserFot);
        console2.log("");

        // Remove liquidity:

        vm.startPrank(fot);
        ERC20(poolAddress).approve(address(s_router), lpTokensUserFot / 4);
        s_router.removeLiquidity(
            address(s_fotToken),
            address(DAI),
            lpTokensUserFot / 4,
            ADD_10K,
            ADD_10K,
            fot,
            block.timestamp
        );

        console2.log("User Balance DAI 2: ", DAI.balanceOf(fot));
        console2.log("User Balance FOT 2: ", s_fotToken.balanceOf(fot));
        console2.log("User Balance LP  2: ", lpTokensUserFot);
        console2.log("");

        // add liquidity:
        DAI.approve(address(s_router), 100e18);
        s_fotToken.approve(address(s_router), 30e18);

        uint256 poolBalanceBeforeDAI = DAI.balanceOf(poolAddress);
        uint256 poolBalanceBeforeFOT = s_fotToken.balanceOf(poolAddress);

        BubbleV1Types.AddLiquidity memory liquidityFot = BubbleV1Types.AddLiquidity({
            tokenA: address(s_fotToken),
            tokenB: address(DAI),
            amountADesired: 3e18,
            amountBDesired: 14e18,
            amountAMin: 1,
            amountBMin: 1,
            receiver: fot,
            deadline: block.timestamp
        });

        (uint256 amountA, uint256 amountB, uint256 lpTokensMinted) =
            s_router.addLiquidity(liquidityFot);

        console2.log("User Balance DAI 3: ", DAI.balanceOf(fot));
        console2.log("User Balance FOT 3: ", s_fotToken.balanceOf(fot));
        console2.log("User Balance LP  3: ", lpTokensUserFot);
        console2.log("");

        // Remove second liquidity:
        lpTokensUserFot = ERC20(poolAddress).balanceOf(fot);
        ERC20(poolAddress).approve(address(s_router), lpTokensUserFot);
        s_router.removeLiquidity(
            address(s_fotToken), address(DAI), lpTokensUserFot, 1, 1, fot, block.timestamp
        );

        console2.log("User Balance DAI 1: ", DAI.balanceOf(fot));
        console2.log("User Balance FOT 1: ", s_fotToken.balanceOf(fot));
        console2.log("User Balance LP  1: ", lpTokensUserFot);
        console2.log("");

        vm.stopPrank();
    }

    function test_swap10K_DAIForFOT() public {
        // 1. Lets add some cash to the pool:
        test_createFOTPoolAndAddLiquidityFOTDAI();

        console2.log("initial balance user DAI: ", DAI.balanceOf(fot) / 1e18); // 990000e18
        console2.log("initial balance user FOT: ", s_fotToken.balanceOf(fot) / 1e18); // 1001929e18

        /**
         * SWAP START *
         */
        // 3. Calculate path:
        address[] memory path = new address[](2);
        path[0] = address(DAI);
        path[1] = address(s_fotToken);

        // 4. User don't want raffle tickets: This is not the objetive of this test
        BubbleV1Types.Fraction[5] memory fractionTiers = [
            BubbleV1Types.Fraction({ numerator: NUMERATOR1, denominator: DENOMINATOR_100 }), // 1%
            BubbleV1Types.Fraction({ numerator: NUMERATOR2, denominator: DENOMINATOR_100 }), // 2%
            BubbleV1Types.Fraction({ numerator: NUMERATOR3, denominator: DENOMINATOR_100 }), // 3%
            BubbleV1Types.Fraction({ numerator: NUMERATOR4, denominator: DENOMINATOR_100 }), // 4%
            BubbleV1Types.Fraction({ numerator: NUMERATOR5, denominator: DENOMINATOR_100 }) // 5%
        ];

        BubbleV1Types.Raffle memory raffleParameters = BubbleV1Types.Raffle({
            enter: false,
            fractionOfSwapAmount: fractionTiers[1],
            raffleNftReceiver: fot
        });

        // 5. swap
        vm.startPrank(fot);
        DAI.approve(address(s_router), ADD_10K);
        s_router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            ADD_10K, 1, path, fot, block.timestamp, raffleParameters
        );

        // 6. check the swap:
        console2.log("final balance user DAI: ", DAI.balanceOf(fot) / 1e18);
        console2.log("final balance user FOT: ", s_fotToken.balanceOf(fot) / 1e18);

        // 7. New swap, 100 DAI:
        DAI.approve(address(s_router), 100e18);
        s_router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            100e18, 1, path, fot, block.timestamp, raffleParameters
        );

        console2.log("final balance user DAI: ", DAI.balanceOf(fot) / 1e18);
        console2.log("final balance user FOT: ", s_fotToken.balanceOf(fot) / 1e18);

        // 8. New swap, 1 DAI:
        DAI.approve(address(s_router), 1e18);
        s_router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            1e18, 1, path, fot, block.timestamp, raffleParameters
        );

        console2.log("final balance user DAI: ", DAI.balanceOf(fot) / 1e18);
        console2.log("final balance user FOT: ", s_fotToken.balanceOf(fot) / 1e18);

        vm.stopPrank();
    }

    function test_swap10K_FOTForDAI() public {
        // 1. Lets add some cash to the pool:
        test_createFOTPoolAndAddLiquidityFOTDAI();

        // 2. A few checks before the start:
        /* address pool = s_factory.getTokenPairToPool(address(s_fotToken), address(DAI));

        uint256 balance_fot_DAI = DAI.balanceOf(fot);
        uint256 balance_fot_FOT = s_fotToken.balanceOf(fot);
        uint256 balance_pool_DAI = DAI.balanceOf(pool);
        uint256 balance_pool_FOT = s_fotToken.balanceOf(pool); */
        console2.log("initial balance user DAI: ", DAI.balanceOf(fot) / 1e18); // 990000e18
        console2.log("initial balance user FOT: ", s_fotToken.balanceOf(fot) / 1e18); // 1001929e18

        /**
         * SWAP START *
         */
        // 3. Calculate path:
        address[] memory path = new address[](2);
        path[0] = address(s_fotToken);
        path[1] = address(DAI);

        // 4. User don't want raffle tickets: This is not the objetive of this test
        BubbleV1Types.Fraction[5] memory fractionTiers = [
            BubbleV1Types.Fraction({ numerator: NUMERATOR1, denominator: DENOMINATOR_100 }), // 1%
            BubbleV1Types.Fraction({ numerator: NUMERATOR2, denominator: DENOMINATOR_100 }), // 2%
            BubbleV1Types.Fraction({ numerator: NUMERATOR3, denominator: DENOMINATOR_100 }), // 3%
            BubbleV1Types.Fraction({ numerator: NUMERATOR4, denominator: DENOMINATOR_100 }), // 4%
            BubbleV1Types.Fraction({ numerator: NUMERATOR5, denominator: DENOMINATOR_100 }) // 5%
        ];

        BubbleV1Types.Raffle memory raffleParameters = BubbleV1Types.Raffle({
            enter: false,
            fractionOfSwapAmount: fractionTiers[1],
            raffleNftReceiver: fot
        });

        // 5. swap
        vm.startPrank(fot);
        s_fotToken.approve(address(s_router), ADD_10K);
        s_router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            ADD_10K, 1, path, fot, block.timestamp, raffleParameters
        );

        // 6. check the swap, not the formula yet @audit-note
        console2.log("after 10K balance user DAI: ", DAI.balanceOf(fot) / 1e18); // 990000e18
        console2.log("after 10K balance user FOT: ", s_fotToken.balanceOf(fot) / 1e18); // 1001929e18

        // 7. New swapp 100 FOT
        vm.startPrank(fot);
        s_fotToken.approve(address(s_router), 100e18);
        s_router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            100e18, 1, path, fot, block.timestamp, raffleParameters
        );

        console2.log("after 100 balance user DAI: ", DAI.balanceOf(fot) / 1e18); // 990000e18
        console2.log("after 100 balance user FOT: ", s_fotToken.balanceOf(fot) / 1e18); // 1001929e18

        // 7. New swapp 1 FOT
        vm.startPrank(fot);
        s_fotToken.approve(address(s_router), 1e18);
        s_router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            1e18, 1, path, fot, block.timestamp, raffleParameters
        );

        console2.log("after 1 balance user DAI: ", DAI.balanceOf(fot) / 1e18); // 990000e18
        console2.log("after 1 balance user FOT: ", s_fotToken.balanceOf(fot) / 1e18); // 1001929e18

        vm.stopPrank();
    }

    // ----------------------------------
    //    swap Native
    // ----------------------------------

    function test_initialSupplyAddNative_FOT() public {
        vm.startPrank(fot);
        s_fotToken.approve(address(s_router), ADD_500K);

        BubbleV1Types.AddLiquidityNative memory nativeFOT = BubbleV1Types.AddLiquidityNative({
            token: address(s_fotToken),
            amountTokenDesired: ADD_500K,
            amountTokenMin: 1,
            amountNativeTokenMin: 1,
            receiver: fot,
            deadline: block.timestamp
        });

        (uint256 amountToken, uint256 amountNative, uint256 lpTokensMinted) =
            s_router.addLiquidityNative{ value: ADD_500K }(nativeFOT);
        vm.stopPrank();

        address poolAddress = s_factory.getTokenPairToPool(address(wMonad), address(s_fotToken));

        /*
         * CHECKS
         */
        assertEq(wMonad.balanceOf(poolAddress), ADD_500K);
        assertEq(s_fotToken.balanceOf(poolAddress), ADD_500K - 15000e18);
        assert(ERC20(poolAddress).balanceOf(fot) != 0);
        assertEq(ERC20(poolAddress).balanceOf(fot), lpTokensMinted);
        assertEq(ERC20(poolAddress).balanceOf(address(1)), 1000);
        assertEq(
            ERC20(poolAddress).balanceOf(fot),
            ERC20(poolAddress).totalSupply() - ERC20(poolAddress).balanceOf(address(1))
        );
    }

    function test_swapExactNativeForTokensSupportingFeeOnTransferTokens() public {
        test_initialSupplyAddNative_FOT();
        address poolAddress = s_factory.getTokenPairToPool(address(wMonad), address(s_fotToken));

        console2.log("***** USER BALANCES BEFORE *****");
        console2.log("Native balance: ", fot.balance);
        console2.log("Fot balance: ", s_fotToken.balanceOf(fot));
        console2.log("");

        address[] memory path = new address[](2);
        path[0] = s_wNative;
        path[1] = address(s_fotToken);

        // 4. User don't want raffle tickets: This is not the objetive of this test
        BubbleV1Types.Fraction[5] memory fractionTiers = [
            BubbleV1Types.Fraction({ numerator: NUMERATOR1, denominator: DENOMINATOR_100 }), // 1%
            BubbleV1Types.Fraction({ numerator: NUMERATOR2, denominator: DENOMINATOR_100 }), // 2%
            BubbleV1Types.Fraction({ numerator: NUMERATOR3, denominator: DENOMINATOR_100 }), // 3%
            BubbleV1Types.Fraction({ numerator: NUMERATOR4, denominator: DENOMINATOR_100 }), // 4%
            BubbleV1Types.Fraction({ numerator: NUMERATOR5, denominator: DENOMINATOR_100 }) // 5%
        ];

        BubbleV1Types.Raffle memory raffleParameters = BubbleV1Types.Raffle({
            enter: false,
            fractionOfSwapAmount: fractionTiers[2],
            raffleNftReceiver: address(fot)
        });

        vm.startPrank(fot);

        s_router.swapExactNativeForTokensSupportingFeeOnTransferTokens{ value: ADD_100K }(
            1, path, swapper1, block.timestamp, raffleParameters
        );

        console2.log("***** USER BALANCES AFTER *****");
        console2.log("Native balance: ", fot.balance);
        console2.log("Fot balance: ", s_fotToken.balanceOf(fot));
        console2.log("");

        s_router.swapExactNativeForTokensSupportingFeeOnTransferTokens{ value: 100e18 }(
            1, path, swapper1, block.timestamp, raffleParameters
        );

        console2.log("***** USER BALANCES AFTER *****");
        console2.log("Native balance: ", fot.balance);
        console2.log("Fot balance: ", s_fotToken.balanceOf(fot));
        console2.log("");

        s_router.swapExactNativeForTokensSupportingFeeOnTransferTokens{ value: 1e18 }(
            1, path, swapper1, block.timestamp, raffleParameters
        );

        console2.log("***** USER BALANCES AFTER *****");
        console2.log("Native balance: ", fot.balance);
        console2.log("Fot balance: ", s_fotToken.balanceOf(fot));
        console2.log("");

        vm.stopPrank();
    }

    function test_swapExactTokensForNativeSupportingFeeOnTransferTokens() public {
        test_initialSupplyAddNative_FOT();
        address poolAddress = s_factory.getTokenPairToPool(address(wMonad), address(s_fotToken));
        console2.log("address pool: ", poolAddress);

        console2.log("***** USER BALANCES BEFORE *****");
        console2.log("Native balance: ", fot.balance);
        console2.log("DAI balance: ", s_fotToken.balanceOf(fot));

        address[] memory path = new address[](2);
        path[0] = address(s_fotToken);
        path[1] = s_wNative;

        // 4. User don't want raffle tickets: This is not the objetive of this test
        BubbleV1Types.Fraction[5] memory fractionTiers = [
            BubbleV1Types.Fraction({ numerator: NUMERATOR1, denominator: DENOMINATOR_100 }), // 1%
            BubbleV1Types.Fraction({ numerator: NUMERATOR2, denominator: DENOMINATOR_100 }), // 2%
            BubbleV1Types.Fraction({ numerator: NUMERATOR3, denominator: DENOMINATOR_100 }), // 3%
            BubbleV1Types.Fraction({ numerator: NUMERATOR4, denominator: DENOMINATOR_100 }), // 4%
            BubbleV1Types.Fraction({ numerator: NUMERATOR5, denominator: DENOMINATOR_100 }) // 5%
        ];

        BubbleV1Types.Raffle memory raffleParameters = BubbleV1Types.Raffle({
            enter: false,
            fractionOfSwapAmount: fractionTiers[2],
            raffleNftReceiver: address(fot)
        });

        vm.startPrank(fot);

        s_fotToken.approve(address(s_router), ADD_10K);
        s_router.swapExactTokensForNativeSupportingFeeOnTransferTokens(
            ADD_10K, 1, path, fot, block.timestamp, raffleParameters
        );

        console2.log("***** USER BALANCES AFTER *****");
        console2.log("Native balance: ", fot.balance);
        console2.log("DAI balance: ", s_fotToken.balanceOf(fot));
        console2.log("");

        s_fotToken.approve(address(s_router), 100e18);
        s_router.swapExactTokensForNativeSupportingFeeOnTransferTokens(
            100e18, 1, path, fot, block.timestamp, raffleParameters
        );

        console2.log("***** USER BALANCES AFTER *****");
        console2.log("Native balance: ", fot.balance);
        console2.log("DAI balance: ", s_fotToken.balanceOf(fot));
        console2.log("");

        s_fotToken.approve(address(s_router), 1e18);
        s_router.swapExactTokensForNativeSupportingFeeOnTransferTokens(
            1e18, 1, path, fot, block.timestamp, raffleParameters
        );

        console2.log("***** USER BALANCES AFTER *****");
        console2.log("Native balance: ", fot.balance);
        console2.log("DAI balance: ", s_fotToken.balanceOf(fot));
        console2.log("");

        vm.stopPrank();
    }

    function test_removeLiquidityNativeSupportingFeeOnTransferTokens() public {
        test_initialSupplyAddNative_FOT();
        address poolAddress = s_factory.getTokenPairToPool(address(wMonad), address(s_fotToken));
        uint256 lpTokensUser = ERC20(poolAddress).balanceOf(fot);

        console2.log("***** USER BALANCES BEFORE *****");
        console2.log("Native balance: ", fot.balance);
        console2.log("DAI balance: ", s_fotToken.balanceOf(fot));
        console2.log("lpTokensUser: ", lpTokensUser);
        console2.log("");

        console2.log("***** POOL BALANCES BEFORE *****");
        console2.log("Native balance: ", wMonad.balanceOf(poolAddress));
        console2.log("DAI balance: ", s_fotToken.balanceOf(poolAddress));
        console2.log("");

        vm.startPrank(fot);
        ERC20(poolAddress).approve(address(s_router), lpTokensUser);
        s_router.removeLiquidityNativeSupportingFeeOnTransferTokens(
            address(s_fotToken), lpTokensUser / 4, 1, 1, fot, block.timestamp
        );
        vm.stopPrank();

        console2.log("***** USER BALANCES AFTER *****");
        console2.log("Native balance: ", fot.balance);
        console2.log("DAI balance: ", s_fotToken.balanceOf(fot));
    }

    function test_removeLiquidityNativeWithPermitSupportingFeeOnTransferTokens() public { }
}
