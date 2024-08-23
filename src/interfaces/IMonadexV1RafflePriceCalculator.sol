// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { MonadexV1Types } from "../library/MonadexV1Types.sol";

interface IMonadexV1RafflePriceCalculator {
    function getPricePerTicket() external pure returns (uint256);

    function getPythPriceFeedContractAddress() external view returns (address);

    function getPythPriceFeedConfigForToken(
        address _token
    )
        external
        view
        returns (MonadexV1Types.PriceFeedConfig memory);
}
