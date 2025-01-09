// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { MonadexV1Types } from "../library/MonadexV1Types.sol";

interface IMonadexV1Raffle {
    function supportToken(
        address _token,
        MonadexV1Types.PriceFeedConfig memory _priceFeedConfig
    )
        external;

    function removeToken(address _token) external;

    function setWinningPortions(MonadexV1Types.Fraction[3] memory _winningPortions) external;

    function setMinimumNftsToBeMintedEachEpoch(uint256 _minimumNftsToBeMintedEachEpoch) external;

    function enterRaffle(
        address _token,
        uint256 _amount,
        address _receiver
    )
        external
        returns (uint256);

    function requestRandomNumber(bytes32 _userRandomNumber) external payable returns (uint64);

    function claimTierWinnings(MonadexV1Types.RaffleClaim memory _claim) external;

    function getEpochDuration() external pure returns (uint256);

    function getTiers() external pure returns (uint256);

    function getWinnersInTier1() external pure returns (uint256);

    function getWinnersInTier2() external pure returns (uint256);

    function getWinnersInTier3() external pure returns (uint256);

    function getMonadexV1Router() external view returns (address);

    function getPyth() external view returns (address);

    function getEntropyContract() external view returns (address);

    function getEntropyProvider() external view returns (address);

    function getSupportedTokens() external view returns (address[] memory);

    function getTokenPriceFeedConfig(
        address _token
    )
        external
        view
        returns (MonadexV1Types.PriceFeedConfig memory);

    function getCurrentSequenceNumber() external view returns (uint64);

    function getCurrentEpoch() external view returns (uint256);

    function getNextTokenId() external view returns (uint256);

    function getLastDrawTimestamp() external view returns (uint256);

    function getMinimumNftsToBeMintedEachEpoch() external view returns (uint256);

    function getUserNftsEachEpoch(
        address _user,
        uint256 _epoch
    )
        external
        view
        returns (uint256[] memory);

    function getNftsMintedEachEpoch(uint256 _epoch) external view returns (uint256);

    function getNftToRange(uint256 _tokenId) external view returns (uint256[] memory);

    function getEpochToRangeEndingPoint(uint256 _epoch) external view returns (uint256);

    function getTokenAmountCollectedInEpoch(
        uint256 _epoch,
        address _token
    )
        external
        view
        returns (uint256);

    function getEpochToRandomNumbersSupplied(
        uint256 _epoch
    )
        external
        view
        returns (uint256[] memory);

    function hasUserClaimedTierWinningsForEpoch(
        address _user,
        uint256 _epoch,
        uint8 _tier
    )
        external
        view
        returns (bool);

    function isSupportedToken(address _token) external view returns (bool);
}
