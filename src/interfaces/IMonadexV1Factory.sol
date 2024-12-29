// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { MonadexV1Types } from "../library/MonadexV1Types.sol";

interface IMonadexV1Factory {
    function deployPool(address _tokenA, address _tokenB) external returns (address);

    function setProtocolTeamMultisig(address _protocolTeamMultisig) external;

    function setProtocolFee(MonadexV1Types.Fraction memory _protocolFee) external;

    function setBlackListedToken(address _token, bool _isBlacklisted) external;

    function setTokenPairFee(address _tokenA, address _tokenB, uint256 _feeTier) external;

    function lockPool(address _pool) external;

    function unlockPool(address _pool) external;

    function getProtocolTeamMultisig() external view returns (address);

    function getProtocolFee() external view returns (MonadexV1Types.Fraction memory);

    function getTokenPairToFee(
        address _tokenA,
        address _tokenB
    )
        external
        view
        returns (MonadexV1Types.Fraction memory);

    function getFeeForAllFeeTiers() external view returns (MonadexV1Types.Fraction[5] memory);

    function getFeeForTier(
        uint256 _feeTier
    )
        external
        view
        returns (MonadexV1Types.Fraction memory);

    function getAllPools() external view returns (address[] memory);

    function precalculatePoolAddress(
        address _tokenA,
        address _tokenB
    )
        external
        view
        returns (address);

    function getTokenPairToPool(address _tokenA, address _tokenB) external view returns (address);

    function isSupportedToken(address _token) external view returns (bool);
}
