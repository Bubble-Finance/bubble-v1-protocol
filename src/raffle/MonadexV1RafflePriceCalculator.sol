// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { MonadexV1Library } from "../library/MonadexV1Library.sol";
import { IPyth } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import { PythStructs } from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import { PythUtils } from "@pythnetwork/pyth-sdk-solidity/PythUtils.sol";

/**
 * @title MonadexV1RafflePriceCalculator.
 * @author Monadex Labs -- mgnfy-view.
 * @notice
 */
contract MonadexV1RafflePriceCalculator {
    // The price of each raffle ticket is $5
    uint256 internal constant PRICE_PER_TICKET = 5;
    // This is the contract we query to get the price of each supported token in USD
    IPyth internal immutable i_pyth;
    // Each supported token has a corresponding token/USD price feed Id
    // once set, this mustn't be changed
    mapping(address token => bytes32 priceFeedId) internal s_tokenToPriceFeedId;

    /**
     * @notice Initializes the pyth contract with the pyth price feed contract address.
     * @param _pythPriceFeedContract The address of the contract to query to get prices for tokens.
     */
    constructor(address _pythPriceFeedContract) {
        i_pyth = IPyth(_pythPriceFeedContract);
    }

    //////////////////////////
    /// External Functions ///
    //////////////////////////

    /**
     * @notice Gets the address of the pyth price feed contract.
     * @return Address of the pyth price feed contract.
     */
    function getPythAddress() external view returns (address) {
        return address(i_pyth);
    }

    /**
     * @notice Gets the token/USD price feed Id for a given token.
     * @param _token The token address.
     * @return The bytes32 price feed Id for the given token.
     */
    function getPriceFeedIdForToken(address _token) external view returns (bytes32) {
        return s_tokenToPriceFeedId[_token];
    }

    /**
     * @notice Gets the price of a ticket in dollars.
     * @return The ticket price in dollars.
     */
    function getPricePerTicket() external pure returns (uint256) {
        return PRICE_PER_TICKET;
    }

    /////////////////////////
    /// Internal Function ///
    /////////////////////////

    /**
     * @notice Gets the tickets to mint for a given token amount. The pyth price feed is used to
     * obtain the total value of the token amount in USD.
     * @param _token The token address.
     * @param _amount The token amount.
     * @return The amount of tickets to mint.
     */
    function _getTicketsToMint(address _token, uint256 _amount) internal view returns (uint256) {
        PythStructs.Price memory price = i_pyth.getPrice(s_tokenToPriceFeedId[_token]);
        return MonadexV1Library.calculateTicketsToMint(
            _amount, price.price, price.expo, PRICE_PER_TICKET
        );
    }
}
