// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BubbleV1Types } from "@src/library/BubbleV1Types.sol";

interface IBubbleV1Pool {
    function initialize(address _tokenA, address _tokenB) external;

    function addLiquidity(address _receiver) external returns (uint256);

    function removeLiquidity(address _receiver) external returns (uint256, uint256);

    function swap(BubbleV1Types.SwapParams memory _swapParams) external;

    function syncBalancesBasedOnReserves(address _receiver) external;

    function syncReservesBasedOnBalances() external;

    function lockPool() external;

    function unlockPool() external;

    function isPoolToken(address _token) external view returns (bool);

    function getFactory() external view returns (address);

    function getTWAPData() external view returns (uint32, uint256, uint256);

    function getProtocolTeamMultisig() external view returns (address);

    function getProtocolFee() external view returns (BubbleV1Types.Fraction memory);

    function getPoolFee() external view returns (BubbleV1Types.Fraction memory);

    function getPoolTokens() external view returns (address, address);

    function getReserves() external view returns (uint256, uint256);
}
