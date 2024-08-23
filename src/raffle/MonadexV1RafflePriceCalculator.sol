// Layout:
//     - pragma
//     - imports
//     - interfaces, libraries, contracts
//     - type declarations
//     - state variables
//     - events
//     - errors
//     - modifiers
//     - functions
//         - constructor
//         - receive function (if exists)
//         - fallback function (if exists)
//         - external
//         - public
//         - internal
//         - private
//         - view and pure functions

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IPyth } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

import { PythStructs } from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import { PythUtils } from "@pythnetwork/pyth-sdk-solidity/PythUtils.sol";

import { IMonadexV1RafflePriceCalculator } from "../interfaces/IMonadexV1RafflePriceCalculator.sol";

import { MonadexV1Library } from "../library/MonadexV1Library.sol";
import { MonadexV1Types } from "../library/MonadexV1Types.sol";

/**
 * @title MonadexV1RafflePriceCalculator.
 * @author Monadex Labs -- mgnfy-view.
 * @notice This contract calculates the amount of tickets to mint for a given token
 * amount using Pyth price feeds.
 */
abstract contract MonadexV1RafflePriceCalculator is IMonadexV1RafflePriceCalculator {
    ///////////////////////
    /// State Variables ///
    ///////////////////////

    /**
     * @dev The price of each raffle ticket is $1.
     */
    uint256 internal constant PRICE_PER_TICKET = 1;

    /**
     * @dev This is the contract we query to get the price of each supported token in USD.
     */
    address internal immutable i_pyth;
    /**
     * @dev Each supported token has a corresponding token/USD price feed Id.
     */
    mapping(address token => MonadexV1Types.PriceFeedConfig config) internal
        s_tokenToPriceFeedConfig;

    ///////////////////
    /// Constructor ///
    ///////////////////

    /**
     * @notice Initializes the Pyth contract with the Pyth price feed contract address.
     * @param _pythPriceFeedContract The address of the contract to query the prices for tokens.
     */
    constructor(address _pythPriceFeedContract) {
        i_pyth = _pythPriceFeedContract;
    }

    /////////////////////////
    /// Internal Function ///
    /////////////////////////

    /**
     * @notice Gets the tickets to mint for a given token amount. Pyth price feeds are used to
     * obtain the total value of the token amount in USD.
     * @param _token The token address.
     * @param _amount The token amount.
     * @return The amount of tickets to mint.
     */
    function _getTicketsToMint(address _token, uint256 _amount) internal view returns (uint256) {
        MonadexV1Types.PriceFeedConfig memory config = s_tokenToPriceFeedConfig[_token];
        PythStructs.Price memory price =
            IPyth(i_pyth).getPriceNoOlderThan(config.priceFeedId, config.noOlderThan);

        return MonadexV1Library.calculateTicketsToMint(_amount, price, PRICE_PER_TICKET);
    }

    //////////////////////////////
    /// View and Pure Function ///
    //////////////////////////////

    /**
     * @notice Gets the price of a ticket in dollars.
     * @return The ticket price in dollars, with 0 decimal precision.
     */
    function getPricePerTicket() external pure returns (uint256) {
        return PRICE_PER_TICKET;
    }

    /**
     * @notice Gets the address of the pyth price feed contract.
     * @return Address of the pyth price feed contract.
     */
    function getPythPriceFeedContractAddress() external view returns (address) {
        return i_pyth;
    }

    /**
     * @notice Gets the token/USD price feed config for a given token.
     * @param _token The token's address.
     * @return The price feed config for the given token.
     */
    function getPythPriceFeedConfigForToken(
        address _token
    )
        external
        view
        returns (MonadexV1Types.PriceFeedConfig memory)
    {
        return s_tokenToPriceFeedConfig[_token];
    }
}
