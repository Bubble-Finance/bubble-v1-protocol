// Layout:
//     - pragma
//     - imports
//     - interfaces, libraries, contracts
//     - type declarations
//     - state variables
//     - events
//     - errors
//     - modifiers
//     - functions
//         - constructor
//         - receive function (if exists)
//         - fallback function (if exists)
//         - external
//         - public
//         - internal
//         - private
//         - view and pure functions

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title MonadexV1Raffle
 * @author Monadex Labs -- Ola Hamid
 * @notice This contract abstracts away the process of requesting for random words
 * from an on-chain VRF service
 */
contract MonadexV1RandomNumberGenerator {
    //////////////////////////
    /// Internal Functions ///
    //////////////////////////

    function _requestRandomWord() internal returns (uint256) {
        // this is a case of weak randomness, which can be easily exploited
        // however, this is a temporary solution and won't go over to mainnet
        // once we get a VRF service on Monad, we'll change the implementation here
        return uint256(block.timestamp + block.prevrandao);
    }
}
