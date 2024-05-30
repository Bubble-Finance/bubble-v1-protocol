// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IPyth } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import { PythStructs } from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract MonadexV1PriceCalculator {
    IPyth internal s_pyth;
    mapping(address token => bytes32 priceFeedID) internal s_tokenToPriceFeedID;

    function getFinalPrice(address _token, uint256 _amount) internal view returns (uint256) {
        PythStructs.Price memory price = s_pyth.getPrice(s_tokenToPriceFeedID[_token]);
        return _amount;
    }

    function getPythAddress() external view returns (address) {
        return address(s_pyth);
    }
}
