// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IMonadexV1Raffle {
    function purchaseTickets(
        address _tokenA,
        address _tokenB,
        uint256 _amountA,
        uint256 _amountB,
        address _receiver
    )
        external
        returns (uint256);
}
