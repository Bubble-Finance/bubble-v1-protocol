// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IMonadexV1Callee {
    /// @notice Called once the contract receives the requested tokens.
    /// @param _caller The address which initiated the swap.
    /// @param _amountAOut The amount of token A sent to the contract.
    /// @param _amountBOut The amount of token B sent to the contract.
    /// @param _data Optional bytes data.
    function onCall(
        address _caller,
        uint256 _amountAOut,
        uint256 _amountBOut,
        bytes calldata _data
    )
        external;

    /// @notice Called before tokens have been received
    /// @param _caller The address which initiated the swap.
    /// @param _amountAOut The amount of token A to send to the contract.
    /// @param _amountBOut The amount of token B to send to the contract.
    /// @param _data Optional bytes data.
    function hookBeforeCall(
        address _caller,
        uint256 _amountAOut,
        uint256 _amountBOut,
        bytes calldata _data
    )
        external;

    /// @notice Called before tokens have been received
    /// @param _caller The address which initiated the swap.
    /// @param _amountAOut The amount of token A that was sent to the contract.
    /// @param _amountBOut The amount of token B that was sent to the contract.
    /// @param _data Optional bytes data.
    function hookAfterCall(
        address _caller,
        uint256 _amountAOut,
        uint256 _amountBOut,
        bytes calldata _data
    )
        external;
}
