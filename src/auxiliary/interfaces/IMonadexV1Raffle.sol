// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

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

    function drawWinners() external returns (address[MAX_WINNERS] memory);

    function claimWinnings(address _token, address _receiver) external returns (uint256);

    function getLastTimestamp() external view returns (uint256);

    function getSupportedTokens() external view returns (address[] memory);

    function isSupportedToken(address _token) external view returns (bool);

    function getWinnings(address _user, address _token) external view returns (uint256);

    function getCurrentRange() external view returns (uint256);

    function previewPurchase(
        uint256 _amount,
        MonadexV1AuxiliaryTypes.Multipliers _multiplier
    )
        external
        view
        returns (uint256);

    function isRaffleOpen() public view returns (bool);
}
