// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: MonadexV1Router
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
//    Monadex Contracts Imports
// --------------------------------

import { ERC20 } from "lib/solmate/src/tokens/ERC20.sol";

import { Deployer } from "test/baseHelpers/Deployer.sol";

import { MonadexV1Library } from "src/library/MonadexV1Library.sol";
import { MonadexV1Types } from "src/library/MonadexV1Types.sol";

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

        MonadexV1Types.AddLiquidity memory liquidityFot = MonadexV1Types.AddLiquidity({
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
        assertEq(s_fotToken.balanceOf(poolAddress), ADD_50K - 500e18);
        assert(ERC20(poolAddress).balanceOf(fot) != 0);
        assertEq(ERC20(poolAddress).balanceOf(fot), lpTokensMinted);
        assertEq(ERC20(poolAddress).balanceOf(address(1)), 1000);
        assertEq(
            ERC20(poolAddress).balanceOf(fot),
            ERC20(poolAddress).totalSupply() - ERC20(poolAddress).balanceOf(address(1))
        );
    }

    function test_removeLiquidityFOTDAI() public {
        test_createFOTPoolAndAddLiquidityFOTDAI();
        address poolAddress = s_factory.getTokenPairToPool(address(DAI), address(s_fotToken));
        uint256 lpTokensUserFot = ERC20(poolAddress).balanceOf(fot);
        vm.startPrank(fot);
        ERC20(poolAddress).approve(address(s_router), lpTokensUserFot);
        s_router.removeLiquidity(
            address(s_fotToken),
            address(DAI),
            lpTokensUserFot,
            ADD_10K,
            ADD_10K,
            fot,
            block.timestamp
        );
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
        MonadexV1Types.Fraction[5] memory fractionTiers = [
            MonadexV1Types.Fraction({ numerator: NUMERATOR1, denominator: DENOMINATOR_100 }), // 1%
            MonadexV1Types.Fraction({ numerator: NUMERATOR2, denominator: DENOMINATOR_100 }), // 2%
            MonadexV1Types.Fraction({ numerator: NUMERATOR3, denominator: DENOMINATOR_100 }), // 3%
            MonadexV1Types.Fraction({ numerator: NUMERATOR4, denominator: DENOMINATOR_100 }), // 4%
            MonadexV1Types.Fraction({ numerator: NUMERATOR5, denominator: DENOMINATOR_100 }) // 5%
        ];

        MonadexV1Types.Raffle memory raffleParameters = MonadexV1Types.Raffle({
            enter: false,
            fractionOfSwapAmount: fractionTiers[1],
            raffleNftReceiver: fot
        });

        // 5. swap
        vm.startPrank(fot);
        s_fotToken.approve(address(s_router), ADD_10K);
        DAI.approve(address(s_router), ADD_10K);
        s_router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            ADD_10K, 1, path, fot, block.timestamp, raffleParameters
        );
        vm.stopPrank();

        // 6. check the swap:
        console2.log("final balance user DAI: ", DAI.balanceOf(fot) / 1e18);
        console2.log("final balance user FOT: ", s_fotToken.balanceOf(fot) / 1e18);
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
        MonadexV1Types.Fraction[5] memory fractionTiers = [
            MonadexV1Types.Fraction({ numerator: NUMERATOR1, denominator: DENOMINATOR_100 }), // 1%
            MonadexV1Types.Fraction({ numerator: NUMERATOR2, denominator: DENOMINATOR_100 }), // 2%
            MonadexV1Types.Fraction({ numerator: NUMERATOR3, denominator: DENOMINATOR_100 }), // 3%
            MonadexV1Types.Fraction({ numerator: NUMERATOR4, denominator: DENOMINATOR_100 }), // 4%
            MonadexV1Types.Fraction({ numerator: NUMERATOR5, denominator: DENOMINATOR_100 }) // 5%
        ];

        MonadexV1Types.Raffle memory raffleParameters = MonadexV1Types.Raffle({
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
        vm.stopPrank();

        // 6. check the swap, not the formula yet @audit-note
        console2.log("final balance user DAI: ", DAI.balanceOf(fot) / 1e18); // 990000e18
        console2.log("final balance user FOT: ", s_fotToken.balanceOf(fot) / 1e18); // 1001929e18
    }

    // ----------------------------------
    //    swap Native
    // ----------------------------------

    function test_initialSupplyAddNative_FOT() public {
        vm.startPrank(fot);
        s_fotToken.approve(address(s_router), ADD_500K);

        MonadexV1Types.AddLiquidityNative memory nativeFOT = MonadexV1Types.AddLiquidityNative({
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
        assertEq(s_fotToken.balanceOf(poolAddress), ADD_500K - 5000e18);
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
        MonadexV1Types.Fraction[5] memory fractionTiers = [
            MonadexV1Types.Fraction({ numerator: NUMERATOR1, denominator: DENOMINATOR_100 }), // 1%
            MonadexV1Types.Fraction({ numerator: NUMERATOR2, denominator: DENOMINATOR_100 }), // 2%
            MonadexV1Types.Fraction({ numerator: NUMERATOR3, denominator: DENOMINATOR_100 }), // 3%
            MonadexV1Types.Fraction({ numerator: NUMERATOR4, denominator: DENOMINATOR_100 }), // 4%
            MonadexV1Types.Fraction({ numerator: NUMERATOR5, denominator: DENOMINATOR_100 }) // 5%
        ];

        MonadexV1Types.Raffle memory raffleParameters = MonadexV1Types.Raffle({
            enter: false,
            fractionOfSwapAmount: fractionTiers[2],
            raffleNftReceiver: address(fot)
        });

        vm.startPrank(fot);

        s_router.swapExactNativeForTokensSupportingFeeOnTransferTokens{ value: ADD_100K }(
            1, path, swapper1, block.timestamp, raffleParameters
        );
        vm.stopPrank();

        console2.log("***** USER BALANCES AFTER *****");
        console2.log("Native balance: ", fot.balance);
        console2.log("Fot balance: ", s_fotToken.balanceOf(fot));
        console2.log("");
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
        MonadexV1Types.Fraction[5] memory fractionTiers = [
            MonadexV1Types.Fraction({ numerator: NUMERATOR1, denominator: DENOMINATOR_100 }), // 1%
            MonadexV1Types.Fraction({ numerator: NUMERATOR2, denominator: DENOMINATOR_100 }), // 2%
            MonadexV1Types.Fraction({ numerator: NUMERATOR3, denominator: DENOMINATOR_100 }), // 3%
            MonadexV1Types.Fraction({ numerator: NUMERATOR4, denominator: DENOMINATOR_100 }), // 4%
            MonadexV1Types.Fraction({ numerator: NUMERATOR5, denominator: DENOMINATOR_100 }) // 5%
        ];

        MonadexV1Types.Raffle memory raffleParameters = MonadexV1Types.Raffle({
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
        vm.stopPrank();
    }

    function test_removeLiquidityNativeSupportingFeeOnTransferTokens() public {
        test_initialSupplyAddNative_FOT();
        address poolAddress = s_factory.getTokenPairToPool(address(wMonad), address(s_fotToken));
        uint256 lpTokensUser = ERC20(poolAddress).balanceOf(fot);

        console2.log("***** USER BALANCES BEFORE *****");
        console2.log("Native balance: ", fot.balance);
        console2.log("DAI balance: ", s_fotToken.balanceOf(fot));

        vm.startPrank(fot);
        ERC20(poolAddress).approve(address(s_router), lpTokensUser);
        s_router.removeLiquidity(
            address(wMonad),
            address(s_fotToken),
            lpTokensUser,
            ADD_50K / 8,
            ADD_50K / 8,
            LP1,
            block.timestamp
        );
        vm.stopPrank();

        console2.log("***** USER BALANCES AFTER *****");
        console2.log("Native balance: ", fot.balance);
        console2.log("DAI balance: ", s_fotToken.balanceOf(fot));
    }

    function test_removeLiquidityNativeWithPermitSupportingFeeOnTransferTokens() public { }
}
