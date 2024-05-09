// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { MonadexV1Types } from "../../core/library/MonadexV1Types.sol";
import { MonadexV1AuxiliaryTypes } from "../library/MonadexV1AuxiliaryTypes.sol";

interface IMonadexV1Raffle {
    function purchaseTickets(
        address _token,
        uint256 _amount,
        MonadexV1AuxiliaryTypes.Multipliers _multiplier,
        address _receiver
    )
        external
        returns (uint256);

    function register(uint256 _amount) external returns (uint256);

    function drawWinners() external returns (address[6] memory);

    function claimWinnings(address _token, address _receiver) external returns (uint256);

    function getRaffleDuration() external pure returns (uint256);

    function getRegistrationPeriod() external pure returns (uint256);

    function getMaxWinners() external pure returns (uint256);

    function getMaxTiers() external pure returns (uint256);

    function getMaxMultipliers() external pure returns (uint256);

    function getLastTimestamp() external view returns (uint256);

    function getSupportedTokens() external view returns (address[] memory);

    function isSupportedToken(address _token) external view returns (bool);

    function getRangeSize() external view returns (uint256);

    function getUserAtRangeStart(uint256 _rangeStart) external view returns (address);

    function getCurrentRangeEnd() external view returns (uint256);

    function getMultipliersToPercentages(MonadexV1AuxiliaryTypes.Multipliers _multiplier)
        external
        view
        returns (MonadexV1Types.Fee memory);

    function getWinnings(address _user, address _token) external view returns (uint256);

    function previewPurchase(
        uint256 _amount,
        MonadexV1AuxiliaryTypes.Multipliers _multiplier
    )
        external
        view
        returns (uint256);

    function isRegistrationOpen() external view returns (bool);
}
