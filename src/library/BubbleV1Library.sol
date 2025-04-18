// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IBubbleV1Factory } from "@src/interfaces/IBubbleV1Factory.sol";
import { IBubbleV1Pool } from "@src/interfaces/IBubbleV1Pool.sol";

import { PythStructs } from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import { BubbleV1Types } from "@src/library/BubbleV1Types.sol";

/// @title BubbleV1Library.
/// @author Bubble Finance -- mgnfy-view.
/// @notice The library holds utility functions to be used by all other contracts in the protocol.
library BubbleV1Library {
    /// @dev Constant used for TWAP oracle.
    uint224 internal constant Q112 = 2 ** 112;
    /// @dev The confidence should not exceed a certain percentage of the price (in this case, 10%).
    uint256 internal constant MAX_ALLOWED_CONFIDENCE_AS_PERCENTAGE_OF_PRICE_IN_BPS = 1_000;
    /// @dev Basis points.
    uint256 internal constant BPS = 10_000;

    //////////////
    /// Errors ///
    //////////////

    error BubbleV1Library__ReservesZero();
    error BubbleV1Library__InputAmountZero();
    error BubbleV1Library__OutputAmountZero();
    error BubbleV1Library__ZeroAmountIn();
    error BubbleV1Library__InvalidSwapPath();
    error BubbleV1Library__ExcessiveConfidence();

    ///////////////////////////////
    /// View and Pure Functions ///
    ///////////////////////////////

    /// @notice Sorts tokens such that the token with the smaller address value
    /// stands first.
    /// @param _tokenA Address of token A.
    /// @param _tokenB Address of token B.
    /// @return A tuple with sorted token addresses.
    function sortTokens(
        address _tokenA,
        address _tokenB
    )
        internal
        pure
        returns (address, address)
    {
        if (_tokenA < _tokenB) return (_tokenA, _tokenB);
        return (_tokenB, _tokenA);
    }

    /// @notice Gets the pool address given the address of the factory and the
    /// tokens in the pair.
    /// @param _factory The address of the `BubbleV1Factory`.
    /// @param _tokenA Address of the first token in the pair.
    /// @param _tokenB Address of the second token in the pair.
    /// @return Address of the pool.
    function getPool(
        address _factory,
        address _tokenA,
        address _tokenB
    )
        internal
        view
        returns (address)
    {
        return IBubbleV1Factory(_factory).getTokenPairToPool(_tokenA, _tokenB);
    }

    /// @notice Gets the reserves of the pool of the given token pair.
    /// @param _factory The address of the `BubbleV1Factory`.
    /// @param _tokenA Address of the first token in the pair.
    /// @param _tokenB Address of the second token in the pair.
    /// @return Reserve of the first token.
    /// @return Reserve of the second token.
    function getReserves(
        address _factory,
        address _tokenA,
        address _tokenB
    )
        internal
        view
        returns (uint256, uint256)
    {
        (address tokenA, address tokenB) = BubbleV1Library.sortTokens(_tokenA, _tokenB);
        (uint256 reserveA, uint256 reserveB) = IBubbleV1Pool(
            IBubbleV1Factory(_factory).getTokenPairToPool(tokenA, tokenB)
        ).getReserves();

        if (_tokenA == tokenA) return (reserveA, reserveB);
        return (reserveB, reserveA);
    }

    /// @notice Gets the pool fee given the address of the factory and the the token pair.
    /// @param _factory The address of the `BubbleV1Factory`.
    /// @param _tokenA Address of the first token in the pair.
    /// @param _tokenB Address of the second token in the pair.
    /// @return The fee struct, consisting of numerator and denominator fields.
    function getPoolFee(
        address _factory,
        address _tokenA,
        address _tokenB
    )
        internal
        view
        returns (BubbleV1Types.Fraction memory)
    {
        return IBubbleV1Factory(_factory).getTokenPairToFee(_tokenA, _tokenB);
    }

    /// @notice Gets the amount of token B based on the amount of token A and the token
    /// reserves for liquidity supply action.
    /// @param _amountA The amount of A to supply.
    /// @param _reserveA Token A reserve.
    /// @param _reserveB Token B reserve.
    /// @return Amount of token B to supply.
    function quote(
        uint256 _amountA,
        uint256 _reserveA,
        uint256 _reserveB
    )
        internal
        pure
        returns (uint256)
    {
        if (_amountA == 0) revert BubbleV1Library__ZeroAmountIn();
        if (_reserveA == 0 || _reserveB == 0) revert BubbleV1Library__ReservesZero();

        return (_amountA * _reserveB) / _reserveA;
    }

    /// @notice Gets the amount that you'll receive in a swap based on the amount you put in,
    /// the token reserves of the pool, and the pool fee.
    /// @param _amountIn The amount of input token to swap.
    /// @param _reserveIn The reserves of the input token.
    /// @param _reserveOut The reserves of the output token.
    /// @param _poolFee Fee of the pool.
    /// @return The amount of output tokens to receive.
    function getAmountOut(
        uint256 _amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut,
        BubbleV1Types.Fraction memory _poolFee
    )
        internal
        pure
        returns (uint256)
    {
        if (_amountIn == 0) revert BubbleV1Library__InputAmountZero();
        if (_reserveIn == 0 && _reserveOut == 0) revert BubbleV1Library__ReservesZero();

        uint256 amountInAfterFee = _amountIn * (_poolFee.denominator - _poolFee.numerator);
        uint256 numerator = amountInAfterFee * _reserveOut;
        uint256 denominator = (_reserveIn * _poolFee.denominator) + amountInAfterFee;

        return numerator / denominator;
    }

    /// @notice Gets the amount of input token you need to put so as to receive the specified
    /// output token amount.
    /// @param _amountOut The amount of output token you want.
    /// @param _reserveIn The reserves of the input token.
    /// @param _reserveOut The reserves of the output token.
    /// @param _poolFee Fee of the pool.
    /// @return The amount of input tokens.
    function getAmountIn(
        uint256 _amountOut,
        uint256 _reserveIn,
        uint256 _reserveOut,
        BubbleV1Types.Fraction memory _poolFee
    )
        internal
        pure
        returns (uint256)
    {
        if (_amountOut == 0) revert BubbleV1Library__OutputAmountZero();
        if (_reserveIn == 0 && _reserveOut == 0) revert BubbleV1Library__ReservesZero();

        uint256 numerator = (_reserveIn * _amountOut * _poolFee.denominator);
        uint256 denominator = (_reserveOut - _amountOut) * _poolFee.numerator;

        return (numerator / denominator) + 1;
    }

    /// @notice Gets the amounts that will be obtained at each checkpoint of the swap path.
    /// @param _factory The factory's address.
    /// @param _amountIn The input token amount.
    /// @param _path An array of token addresses which forms the swap path.
    /// @return An array which holds the output amounts at each checkpoint of the swap path.
    /// The last element in the array is the actual ouput amount you'll receive.
    function getAmountsOut(
        address _factory,
        uint256 _amountIn,
        address[] calldata _path
    )
        internal
        view
        returns (uint256[] memory)
    {
        if (_path.length < 2) revert BubbleV1Library__InvalidSwapPath();
        uint256[] memory amounts = new uint256[](_path.length);
        amounts[0] = _amountIn;

        for (uint256 count = 0; count < _path.length - 1; ++count) {
            (uint256 reserveIn, uint256 reserveOut) =
                getReserves(_factory, _path[count], _path[count + 1]);
            BubbleV1Types.Fraction memory poolFee =
                getPoolFee(_factory, _path[count], _path[count + 1]);
            amounts[count + 1] = getAmountOut(amounts[count], reserveIn, reserveOut, poolFee);
        }

        return amounts;
    }

    /// @notice Gets the input amounts at each checkpoint of the swap path
    /// @param _factory The factory's address.
    /// @param _amountOut The amount of output tokens you desire.
    /// @param _path An array of token addresses which forms the swap path in case a direct
    /// path does not exist from input token to output token.
    /// @return An array which holds the input amounts at each checkpoint of the swap path.
    function getAmountsIn(
        address _factory,
        uint256 _amountOut,
        address[] memory _path
    )
        internal
        view
        returns (uint256[] memory)
    {
        if (_path.length < 2) revert BubbleV1Library__InvalidSwapPath();
        uint256[] memory amounts = new uint256[](_path.length);
        amounts[amounts.length - 1] = _amountOut;

        for (uint256 count = _path.length - 1; count > 0; --count) {
            (uint256 reserveIn, uint256 reserveOut) =
                getReserves(_factory, _path[count - 1], _path[count]);
            BubbleV1Types.Fraction memory poolFee =
                getPoolFee(_factory, _path[count - 1], _path[count]);
            amounts[count - 1] = getAmountIn(amounts[count], reserveIn, reserveOut, poolFee);
        }

        return amounts;
    }

    /// @notice Encodes a uint112 as a UQ112x112. Utility function to be used by
    /// the TWAP oracle.
    /// @param _number The number to encode.
    /// @return The UQ112x112 encoded number.
    function encode(uint112 _number) internal pure returns (uint224) {
        return uint224(_number) * Q112; // never overflows
    }

    /// @notice Divides a UQ112x112 by a uint112, returning a UQ112x112. Utility function to
    /// be used by the TWAP oracle.
    /// @param _dividend The numerator.
    /// @param _divisor The denominator.
    /// @return The result of division.
    function uqdiv(uint224 _dividend, uint112 _divisor) internal pure returns (uint224) {
        return _dividend / uint224(_divisor);
    }

    /// @notice Gets the part of the initial amount based on the given
    /// percentage.
    /// @param _amount The amount of input token.
    /// @param _percentage The percentage of the amount to take.
    /// @return The amount of after applying the percentage.
    function calculateAmountAfterApplyingPercentage(
        uint256 _amount,
        BubbleV1Types.Fraction memory _percentage
    )
        internal
        pure
        returns (uint256)
    {
        return (_amount * _percentage.numerator) / _percentage.denominator;
    }

    /// @notice Calculates the total value of the token amount in usd.
    /// @param _amount The token amount.
    /// @param _pythPrice The price struct obtained from Pyth.
    /// @param _targetDecimals The target decimals to put the price into.
    /// @return The total value of the token amount in usd.
    function totalValueInUsd(
        uint256 _amount,
        PythStructs.Price memory _pythPrice,
        uint8 _targetDecimals,
        uint256 _decimals
    )
        internal
        pure
        returns (uint256)
    {
        uint256 price = _convertToUint(_pythPrice.price, _pythPrice.expo, _targetDecimals);
        uint256 confidence =
            _convertToUint(int64(_pythPrice.conf), _pythPrice.expo, _targetDecimals);
        if (confidence > (price * MAX_ALLOWED_CONFIDENCE_AS_PERCENTAGE_OF_PRICE_IN_BPS) / BPS) {
            revert BubbleV1Library__ExcessiveConfidence();
        }

        return (_amount * price) / (10 ** _decimals);
    }

    /// @notice Converts a Pyth price to a uint256 with a target number of decimals.
    /// @param _price The Pyth price.
    /// @param _expo The Pyth price exponent.
    /// @param _targetDecimals The target number of decimals.
    /// @return The price as a uint256.
    /// @dev Function will lose precision if targetDecimals is less than the Pyth price decimals.
    /// This method will truncate any digits that cannot be represented by the targetDecimals.
    /// e.g. If the price is 0.000123 and the targetDecimals is 2, the result will be 0.
    function _convertToUint(
        int64 _price,
        int32 _expo,
        uint8 _targetDecimals
    )
        public
        pure
        returns (uint256)
    {
        if (_price < 0 || _expo > 0 || _expo < -255) {
            revert();
        }

        uint8 priceDecimals = uint8(uint32(-1 * _expo));

        if (_targetDecimals >= priceDecimals) {
            return uint256(uint64(_price)) * 10 ** uint32(_targetDecimals - priceDecimals);
        } else {
            return uint256(uint64(_price)) / 10 ** uint32(priceDecimals - _targetDecimals);
        }
    }

    /// @notice Gets the amount of tokens to send to buyer/seller on campaigns based
    /// on input amount, input reserve, and the output reserve.
    /// @param _amountIn The input amount.
    /// @param _reserveIn The reserves of the input token.
    /// @param _reserveOut The reserves of the output token.
    /// @return The amount of output tokens to send to the buyer/seller on campaigns.
    function getAmountOutForCampaigns(
        uint256 _amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut
    )
        internal
        pure
        returns (uint256)
    {
        return (_reserveOut * _amountIn) / (_amountIn + _reserveIn);
    }
}
