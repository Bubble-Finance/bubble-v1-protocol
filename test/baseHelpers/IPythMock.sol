// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract IPythMock is IPyth {
    mapping(bytes32 => PythStructs.Price) public prices;

    function setPrice(bytes32 priceFeedId, int64 price, int32 expo, uint64 conf) external {
        prices[priceFeedId] = PythStructs.Price({
            price: price,
            conf: conf,
            expo: expo,
            publishTime: block.timestamp
        });
    }

    function getValidTimePeriod() external pure override returns (uint256) {
        return 3600; // Default to 1 hour
    }

    function getPrice(
        bytes32 priceFeedId
    )
        external
        view
        override
        returns (PythStructs.Price memory)
    {
        return prices[priceFeedId];
    }

    function getPriceUnsafe(
        bytes32 priceFeedId
    )
        external
        view
        override
        returns (PythStructs.Price memory)
    {
        return prices[priceFeedId];
    }

    function getPriceNoOlderThan(
        bytes32 priceFeedId,
        uint256 age
    )
        external
        view
        override
        returns (PythStructs.Price memory)
    {
        PythStructs.Price memory price = prices[priceFeedId];
        require(price.publishTime + age >= block.timestamp, "Price is too old");
        return price;
    }

    function getEmaPrice(bytes32) external view override returns (PythStructs.Price memory) {
        //return PythStructs.Price(0, 0, 0, 0);
    }

    function getEmaPriceNoOlderThan(
        bytes32,
        uint256
    )
        external
        view
        override
        returns (PythStructs.Price memory)
    {
        //return PythStructs.Price(0, 0, 0, 0);
    }

    function getEmaPriceUnsafe(bytes32) external view override returns (PythStructs.Price memory) {
        //return PythStructs.Price(0, 0, 0, 0);
    }

    function updatePriceFeeds(bytes[] calldata) external payable override { }

    function updatePriceFeedsIfNecessary(
        bytes[] calldata updateData,
        bytes32[] calldata priceIds,
        uint64[] calldata publishTimes
    )
        external
        payable
        override
    { }

    function getUpdateFee(bytes[] calldata) external pure override returns (uint256) {
        return 0;
    }

    function parsePriceFeedUpdates(
        bytes[] calldata,
        bytes32[] calldata,
        uint64,
        uint64
    )
        external
        payable
        override
        returns (PythStructs.PriceFeed[] memory)
    {
        return new PythStructs.PriceFeed[](0);
    }

    function parsePriceFeedUpdatesUnique(
        bytes[] calldata,
        bytes32[] calldata,
        uint64,
        uint64
    )
        external
        payable
        override
        returns (PythStructs.PriceFeed[] memory)
    {
        return new PythStructs.PriceFeed[](0);
    }
}
