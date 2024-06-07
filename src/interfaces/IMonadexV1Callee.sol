// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IMonadexV1Callee {
    // called once the contract receives the requested tokens
    function onCall(
        address _caller,
        uint256 _amountAOut,
        uint256 _amountBOut,
        bytes calldata _data
    )
        external;

    // called before tokens have been received
    function hookBeforeCall(
        address _caller,
        uint256 _amountAOut,
        uint256 _amountBOut,
        bytes calldata _data
    )
        external;

    // called after the swap has been successfully executed
    function hookAfterCall(
        address _caller,
        uint256 _amountAOut,
        uint256 _amountBOut,
        bytes calldata _data
    )
        external;
}
