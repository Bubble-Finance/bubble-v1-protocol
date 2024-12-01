// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { MonadexV1Types } from "../library/MonadexV1Types.sol";

interface IMonadexV1Pool {
    function initialize(address _tokenA, address _tokenB) external;

    function addLiquidity(address _receiver) external returns (uint256);

    function removeLiquidity(address _receiver) external returns (uint256, uint256);

    function swap(MonadexV1Types.SwapParams memory _swapParams) external;

    function syncBalancesBasedOnReserves(address _receiver) external;

    function syncReservesBasedOnBalances() external;

    function lockPool() external;

    function unlockPool() external;

    function isPoolToken(address _token) external view returns (bool);

    function getFactory() external view returns (address);

    function getProtocolTeamMultisig() external view returns (address);

    function getProtocolFee() external view returns (MonadexV1Types.Fraction memory);

    function getPoolFee() external view returns (MonadexV1Types.Fraction memory);

    function getPoolTokens() external view returns (address, address);

    function getReserves() external view returns (uint256, uint256);
}
