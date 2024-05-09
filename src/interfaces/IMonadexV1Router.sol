// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { MonadexV1Types } from "../library/MonadexV1Types.sol";

interface IMonadexV1Router {
    function addLiquidity(MonadexV1Types.AddLiquidity memory _addLiquidityParams)
        external
        returns (uint256, uint256, uint256);

    function removeLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _lpTokensToBurn,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _receiver,
        uint256 _deadline
    )
        external
        returns (uint256, uint256);

    function swapExactTokensForTokens(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path,
        address _receiver,
        uint256 _deadline,
        MonadexV1Types.PurchaseTickets memory _purchaseTickets
    )
        external
        returns (uint256[] memory, uint256);

    function swapTokensForExactTokens(
        uint256 _amountOut,
        uint256 _amountInMax,
        address[] calldata _path,
        address _receiver,
        uint256 _deadline,
        MonadexV1Types.PurchaseTickets memory _purchaseTickets
    )
        external
        returns (uint256[] memory, uint256);
}
