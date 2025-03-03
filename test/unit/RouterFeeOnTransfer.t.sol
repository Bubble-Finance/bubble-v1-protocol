// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ----------------------------------
//  CONTRACT: MonadexV1Router
//  FUNCTIONS TESTED: 6
//  1. removeLiquidityNativeSupportingFeeOnTransferTokens()
//  2. removeLiquidityNativeWithPermitSupportingFeeOnTransferTokens()
//  3. swapExactTokensForTokensSupportingFeeOnTransferTokens()
//  4. swapExactNativeForTokensSupportingFeeOnTransferTokens()
//  5. swapExactTokensForNativeSupportingFeeOnTransferTokens()
//  6. _swapSupportingFeeOnTransferTokens()
// ----------------------------------

// ----------------------------------
//  TEST:
// ----------------------------------

// ----------------------------------
//    Foundry Contracts Imports
// ----------------------------------

import { Test, console } from "lib/forge-std/src/Test.sol";

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

contract RouterFeeOnTransfer is Test, Deployer { }
