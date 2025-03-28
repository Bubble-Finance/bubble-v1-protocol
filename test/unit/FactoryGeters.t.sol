// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: BubbleV1Factory
//  FUNCTIONS TESTED: 8
//  This test check all the get functions of the Factory contract.
// ----------------------------------

// ----------------------------------
//  TEST:
//  1. getProtocolTeamMultisig()
//  2. getProtocolFee()
//  3. getTokenPairToFee()
//  *** @audit-check The pair is not set but the function returns 0.3%
//  **************** Could be ok, as, if the pair is not set, it is created with the firs deposit.
//  4. getFeeForAllFeeTiers()
//  *** Get token pair fee if the fee was changed.
//  5. getFeeForTier().
//  6. getTokenPairToPool()
//  *** Get fee for an specific tier.
//  7. getSupportedToken()
//  *** @audit-check Every token is supported by default.
//  *** That's include ERC777,fake and dangerous tokens....
//  8. getPrepaclculatedPoolAddress()
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

contract FactoryGeters is Test, Deployer {
    function test_getProtocolTeamMultisig() external {
        vm.prank(LP1);
        address PTM = s_factory.getProtocolTeamMultisig();
        assertEq(protocolTeamMultisig, PTM);
    }

    function test_getProtocolFee() external {
        vm.prank(LP1);
        BubbleV1Types.Fraction memory pFee = s_factory.getProtocolFee();
        assertEq(pFee.numerator, 1);
        assertEq(pFee.denominator, 5);
    }

    function test_getTokenPairToFee() external {
        vm.prank(LP1);
        BubbleV1Types.Fraction memory TPF = s_factory.getTokenPairToFee(address(DAI), address(wETH));
        assertEq(TPF.numerator, 3);
    }

    function test_getTokePairFeeThatWasChanged() public {
        vm.prank(protocolTeamMultisig);
        s_factory.setTokenPairFee(address(wETH), address(DAI), 5);
        vm.prank(LP1);
        BubbleV1Types.Fraction memory TPF = s_factory.getTokenPairToFee(address(DAI), address(wETH));
        assertEq(TPF.numerator, 5);
    }

    function test_getFeeForAllFeeTiers() external view {
        BubbleV1Types.Fraction[5] memory AFT = s_factory.getFeeForAllFeeTiers();
        BubbleV1Types.Fraction memory aft0 = AFT[0];
        assertEq(aft0.numerator, 1);
        assertEq(aft0.denominator, 1000);
    }

    function test_getFeeForTier() external view {
        BubbleV1Types.Fraction memory FFT = s_factory.getFeeForTier(5);
        assertEq(FFT.numerator, 5);
    }

    function test_getTokenPairToPool() external {
        vm.startPrank(LP1);
        address newPool = s_factory.deployPool(address(wETH), address(DAI));
        address TPP = s_factory.getTokenPairToPool(address(wETH), address(DAI));
        vm.stopPrank();
        assertEq(newPool, TPP);
    }

    function test_getIfSupportedTokenIsSupported() public {
        vm.startPrank(LP1);
        assertEq(s_factory.isSupportedToken(address(DAI)), true);
        assertEq(s_factory.isSupportedToken(address(wBTC)), true);
        assertEq(s_factory.isSupportedToken(address(SHIB)), true);
        assertEq(s_factory.isSupportedToken(address(DANGER)), true);
        vm.stopPrank();
    }

    function test_getIfUnSupportedTokenIsSupported() public {
        vm.prank(protocolTeamMultisig);
        s_factory.setBlackListedToken(address(DAI), true);
        vm.prank(LP1);
        assertEq(s_factory.isSupportedToken(address(DAI)), false);
    }

    function test_getIfTokenIsSupprtedAgain() public {
        vm.prank(protocolTeamMultisig);
        s_factory.setBlackListedToken(address(DAI), true);
        vm.prank(LP1);
        assertEq(s_factory.isSupportedToken(address(DAI)), false);
        vm.prank(protocolTeamMultisig);
        s_factory.setBlackListedToken(address(DAI), false);
        vm.prank(LP1);
        assertEq(s_factory.isSupportedToken(address(DAI)), true);
    }

    function test_getPrecalculatePoolAddress() public {
        vm.startPrank(LP1);
        address preCalculated = s_factory.precalculatePoolAddress(address(DAI), address(wBTC));
        address deployed = s_factory.deployPool(address(DAI), address(wBTC));
        vm.stopPrank();
        assertEq(preCalculated, deployed);
    }
}
