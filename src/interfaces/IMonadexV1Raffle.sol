// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { MonadexV1Types } from "../library/MonadexV1Types.sol";

interface IMonadexV1Raffle {
    function initializeRouterAddress(address _routerAddress) external;

    function purchaseTickets(
        address _swapper,
        address _token,
        uint256 _amount,
        MonadexV1Types.Multipliers _multiplier,
        address _receiver
    )
        external
        returns (uint256);

    function register(uint256 _amount) external returns (uint256);

    function requestRandomNumber(bytes32 _userRandomNumber) external payable returns (uint64);

    function drawWinnersAndAllocateRewards() external;

    function claimWinnings(address _token, address _receiver) external returns (uint256);

    function supportToken(
        address _token,
        MonadexV1Types.PriceFeedConfig memory _pythPriceFeedConfig
    )
        external;

    function removeToken(address _token) external;

    function getRouterAddress() external view returns (address);

    function getLastTimestamp() external view returns (uint256);

    function getSupportedTokens() external view returns (address[] memory);

    function isSupportedToken(address _token) external view returns (bool);

    function getUserAtRangeStart(uint256 _rangeStart) external view returns (address);

    function getCurrentRangeEnd() external view returns (uint256);

    function getMultiplierToPercentage(
        MonadexV1Types.Multipliers _multiplier
    )
        external
        view
        returns (MonadexV1Types.Fraction memory);

    function getWinningPortions() external view returns (MonadexV1Types.Fraction[3] memory);

    function getWinnings(address _user, address _token) external view returns (uint256);

    function getRaffleDuration() external pure returns (uint256);

    function getRegistrationPeriod() external pure returns (uint256);

    function getMaxWinners() external pure returns (uint256);

    function getMaxTiers() external pure returns (uint256);

    function getMaxMultipliers() external pure returns (uint256);

    function getRangeSize() external view returns (uint256);

    function getMinimumParticipantsForRaffle() external view returns (uint256);

    function previewPurchase(
        address _token,
        uint256 _amount,
        MonadexV1Types.Multipliers _multiplier
    )
        external
        view
        returns (uint256);

    function isRegistrationOpen() external view returns (bool);

    function hasRegistrationPeriodEnded() external view returns (bool);
}
