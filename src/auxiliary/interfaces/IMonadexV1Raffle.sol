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
}
