// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IMonadexV1Callee {
    function onCall(
        address _caller,
        uint256 _amountAOut,
        uint256 _amountBOut,
        bytes calldata _data
    )
        external;

    function hookBeforeCall(
        address _caller,
        uint256 _amountAOut,
        uint256 _amountBOut,
        bytes calldata _data
    )
        external;

    function hookAfterCall(
        address _caller,
        uint256 _amountAOut,
        uint256 _amountBOut,
        bytes calldata _data
    )
        external;
}
