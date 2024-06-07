// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { MonadexV1Types } from "../library/MonadexV1Types.sol";

interface IMonadexV1Factory {
    function deployPool(address _tokenA, address _tokenB) external returns (address);

    function setProtocolTeamMultisig(address _protocolTeamMultisig) external;

    function setProtocolFee(MonadexV1Types.Fee memory _protocolFee) external;

    function setToken(address _token, bool _isSupported) external;

    function setTokenPairFee(address _tokenA, address _tokenB, uint256 _feeTier) external;

    function lockPool(address _pool) external;

    function unlockPool(address _pool) external;

    function getProtocolTeamMultisig() external view returns (address);

    function getProtocolFee() external view returns (MonadexV1Types.Fee memory);

    function getTokenPairToFee(
        address _tokenA,
        address _tokenB
    )
        external
        view
        returns (MonadexV1Types.Fee memory);

    function getFeeForAllFeeTiers() external view returns (MonadexV1Types.Fee[5] memory);

    function getFeeForTier(uint256 _feeTier) external view returns (MonadexV1Types.Fee memory);

    function isSupportedToken(address _token) external view returns (bool);

    function getTokenPairToPool(address _tokenA, address _tokenB) external view returns (address);
}
