// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { MonadexV1Types } from "../library/MonadexV1Types.sol";

interface IMonadexV1Campaigns {
    function setMinimumTokenTotalSupply(uint256 _minimumTokenTotalSupply) external;

    function setMinimumVirtualNativeTokenReserve(
        uint256 _minimumVirtualNativeTokenReserve
    )
        external;

    function setMinimumNativeTokenAmountToRaise(
        uint256 _minimumNativeTokenAmountToRaise
    )
        external;

    function setTokenCreatorReward(uint256 _tokenCreatorReward) external;

    function setLiquidityMigrationFee(uint256 _liquidityMigrationFee) external;

    function setFee(MonadexV1Types.Fraction memory _fee) external;

    function setVault(address _vault) external;

    function collectFees(address _to, uint256 _amount) external;

    function createToken(
        MonadexV1Types.TokenDetails calldata _tokenDetails,
        uint256 _deadline,
        uint256 _initialNativeAmountToBuyWith
    )
        external
        payable
        returns (address);

    function sellTokens(
        address _token,
        uint256 _amount,
        uint256 _minimumWrappedNativeAmountToReceive,
        uint256 _deadline,
        address _receiver
    )
        external;

    function buyTokens(
        address _token,
        uint256 _nativeTokenAmount,
        uint256 _minimumAmountToReceive,
        uint256 _deadline,
        address _receiver
    )
        external
        payable;

    function getMinimumTokenTotalSupply() external view returns (uint256);

    function getMinimumVirutalNativeReserve() external view returns (uint256);

    function getMinimumNativeAmountToRaise() external view returns (uint256);

    function getTokenCreatorReward() external view returns (uint256);

    function getLiquidityMigrationFee() external view returns (uint256);

    function getFee() external view returns (MonadexV1Types.Fraction memory);

    function getFeeCollected() external view returns (uint256);

    function getMonadexV1Router() external view returns (address);

    function getWNative() external view returns (address);

    function getVault() external view returns (address);

    function getTokenCounter() external view returns (uint256);

    function getTokenCountToToken(uint256 _tokenCount) external view returns (address);

    function getTokenDetails(
        address _token
    )
        external
        view
        returns (MonadexV1Types.TokenDetails memory);

    function getRemainingNativeTokenAmountToCompleteBondingCurve(
        address _token
    )
        external
        view
        returns (uint256);

    function previewBuy(
        address _token,
        uint256 _nativeAmount
    )
        external
        view
        returns (uint256, uint256);

    function previewSell(
        address _token,
        uint256 _tokenAmount
    )
        external
        view
        returns (uint256, uint256);
}
