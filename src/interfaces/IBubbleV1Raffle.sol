// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BubbleV1Types } from "@src/library/BubbleV1Types.sol";

interface IBubbleV1Raffle {
    function initializeBubbleV1Router(address _bubbleV1Router) external;

    function setFee(BubbleV1Types.Fraction memory _newFee) external;

    function supportToken(
        address _token,
        BubbleV1Types.PriceFeedConfig memory _priceFeedConfig
    )
        external;

    function removeToken(address _token) external;

    function setWinningPortions(BubbleV1Types.Fraction[3] memory _winningPortions) external;

    function setMinimumNftsToBeMintedEachEpoch(uint256 _minimumNftsToBeMintedEachEpoch) external;

    function collectFees(address _token, uint256 _amount, address _receiver) external;

    function boostRewards(address _token, uint256 _amount) external;

    function enterRaffle(
        address _token,
        uint256 _amount,
        address _receiver
    )
        external
        returns (uint256);

    function requestRandomNumber(bytes32 _userRandomNumber) external payable;

    function claimTierWinnings(BubbleV1Types.RaffleClaim memory _claim) external;

    function getEpochDuration() external pure returns (uint256);

    function getTiers() external pure returns (uint256);

    function getWinnersInTier1() external pure returns (uint256);

    function getWinnersInTier2() external pure returns (uint256);

    function getWinnersInTier3() external pure returns (uint256);

    function getBubbleV1Router() external view returns (address);

    function getPyth() external view returns (address);

    function getFee() external view returns (BubbleV1Types.Fraction memory);

    function getEntropyContract() external view returns (address);

    function getEntropyProvider() external view returns (address);

    function getSupportedTokens() external view returns (address[] memory);

    function getTokenPriceFeedConfig(
        address _token
    )
        external
        view
        returns (BubbleV1Types.PriceFeedConfig memory);

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

    function getNftToRange(uint256[] memory _tokenIds) external view returns (uint256[][] memory);

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
        uint256 _tokenId,
        uint256 _epoch,
        BubbleV1Types.Tiers _tier
    )
        external
        view
        returns (bool);

    function isSupportedToken(address _token) external view returns (bool);

    function getTimeRemainingUntilNextEpoch() external view returns (uint256);

    function getWinnings(
        BubbleV1Types.RaffleClaim memory _claim
    )
        external
        view
        returns (BubbleV1Types.Winnings[] memory);
}
