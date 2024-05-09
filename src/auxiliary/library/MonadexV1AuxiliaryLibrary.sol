// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IMonadexV1Factory } from "../../core/interfaces/IMonadexV1Factory.sol";
import { IMonadexV1Pool } from "../../core/interfaces/IMonadexV1Pool.sol";

import { MonadexV1Types } from "../../core/library/MonadexV1Types.sol";
import { MonadexV1Utils } from "../../core/library/MonadexV1Utils.sol";
import { MonadexV1AuxiliaryTypes } from "./MonadexV1AuxiliaryTypes.sol";

library MonadexV1AuxiliaryLibrary {
    error MonadexV1AuxiliaryLibrary__ZeroReserves();
    error MonadexV1AuxiliaryLibrary__ZeroAmountIn();
    error MonadexV1AuxiliaryLibrary__InvalidSwapPath();
    error MonadexV1AuxiliaryLibrary__InputAmountZero();
    error MonadexV1AuxiliaryLibrary__OutputAmountZero();
    error MonadexV1AuxiliaryLibrary__ReservesZero();

    /**
     * @notice Gets the pool address given the address of the factory and the
     * tokens in the combination.
     * @param _factory The address of the MonadexV1Factory.
     * @param _tokenA Address of the first token in the combination.
     * @param _tokenB Address of the second token in the combination.
     * @return Address of the pool.
     */
    function getPool(
        address _factory,
        address _tokenA,
        address _tokenB
    )
        internal
        view
        returns (address)
    {
        return IMonadexV1Factory(_factory).getTokenPairToPool(_tokenA, _tokenB);
    }

    /**
     * @notice Gets the reserves of the pool of the given token combination.
     * @param _factory The address of the MonadexV1Factory.
     * @param _tokenA Address of the first token in the combination.
     * @param _tokenB Address of the second token in the combination.
     * @return Reserve of the first token.
     * @return Reserve of the second token.
     */
    function getReserves(
        address _factory,
        address _tokenA,
        address _tokenB
    )
        internal
        view
        returns (uint256, uint256)
    {
        (address tokenA, address tokenB) = MonadexV1Utils.sortTokens(_tokenA, _tokenB);
        (uint256 reserveA, uint256 reserveB) = IMonadexV1Pool(
            IMonadexV1Factory(_factory).getTokenPairToPool(tokenA, tokenB)
        ).getReserves();

        if (_tokenA == tokenA) return (reserveA, reserveB);
        else return (reserveB, reserveA);
    }

    /**
     * @notice Gets the pool fee given the address of the factory and the the tokens in
     * the combination.
     * @param _factory The address of the MonadexV1Factory.
     * @param _tokenA Address of the first token in the combination.
     * @param _tokenB Address of the second token in the combination.
     * @return The fee struct, consisting of numerator and denominator fields.
     */
    function getPoolFee(
        address _factory,
        address _tokenA,
        address _tokenB
    )
        internal
        view
        returns (MonadexV1Types.Fee memory)
    {
        return IMonadexV1Factory(_factory).getTokenPairToFee(_tokenA, _tokenB);
    }

    /**
     * @notice Gets the amount of B based on the amount of A and the token reserves for
     * liquidity supply action.
     * @param _amountA The amount of A to supply.
     * @param _reserveA Token A reserve.
     * @param _reserveB Token A reserve.
     * @return Amount of token B to supply.
     */
    function quote(
        uint256 _amountA,
        uint256 _reserveA,
        uint256 _reserveB
    )
        internal
        pure
        returns (uint256)
    {
        if (_amountA == 0) revert MonadexV1AuxiliaryLibrary__ZeroAmountIn();
        if (_reserveA == 0 || _reserveB == 0) revert MonadexV1AuxiliaryLibrary__ZeroReserves();

        return (_amountA * _reserveB) / _reserveA;
    }

    /**
     * @notice Gets the amount that you'll receive for in a swap based on the amount you put in,
     * the token reserves of the pool, and the pool fee.
     * @param _amountIn The amount of token to swap for the output token.
     * @param _reserveIn The reserves of the input token.
     * @param _reserveOut The reserves of the output token.
     * @param _poolFee Fee of the pool.
     * @return The amount of output tokens to receive.
     */
    function getAmountOut(
        uint256 _amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut,
        MonadexV1Types.Fee memory _poolFee
    )
        internal
        pure
        returns (uint256)
    {
        if (_amountIn == 0) revert MonadexV1AuxiliaryLibrary__InputAmountZero();
        if (_reserveIn == 0 && _reserveOut == 0) revert MonadexV1AuxiliaryLibrary__ReservesZero();

        uint256 amountInAfterFee = _amountIn * (_poolFee.denominator - _poolFee.numerator);
        uint256 numerator = amountInAfterFee * _reserveOut;
        uint256 denominator = (_reserveIn * _poolFee.denominator) + amountInAfterFee;

        return numerator / denominator;
    }

    /**
     * @notice Gets the amount of input token you need to put so as to receive the specified
     * output token amount.
     * @param _amountOut The amount of output token you want.
     * @param _reserveIn The reserves of the input token.
     * @param _reserveOut The reserves of the output token.
     * @param _poolFee Fee of the pool.
     * @return The amount of input tokens.
     */
    function getAmountIn(
        uint256 _amountOut,
        uint256 _reserveIn,
        uint256 _reserveOut,
        MonadexV1Types.Fee memory _poolFee
    )
        internal
        pure
        returns (uint256)
    {
        if (_amountOut == 0) revert MonadexV1AuxiliaryLibrary__OutputAmountZero();
        if (_reserveIn == 0 && _reserveOut == 0) revert MonadexV1AuxiliaryLibrary__ReservesZero();

        uint256 numerator = (_reserveIn * _amountOut * _poolFee.denominator);
        uint256 denominator = (_reserveOut - _amountOut) * _poolFee.numerator;

        return (numerator / denominator) + 1;
    }

    /**
     * @notice Gets the amounts that will be obtained at each checkpoint of the swap path.
     * @param _factory The factory's address.
     * @param _amountIn The input token amount.
     * @param _path An array of token addresses which forms the swap path in case a direct
     * path does not exist from input token to output token.
     * @return An array which holds the output amounts at each checkpoint of the swap path.
     * The last element in the array is the actual ouput amount you'll receive.
     */
    function getAmountsOut(
        address _factory,
        uint256 _amountIn,
        address[] calldata _path
    )
        internal
        view
        returns (uint256[] memory)
    {
        if (_path.length < 2) revert MonadexV1AuxiliaryLibrary__InvalidSwapPath();
        uint256[] memory amounts = new uint256[](_path.length);
        amounts[0] = _amountIn;

        for (uint256 count = 0; count < _path.length - 1; ++count) {
            (uint256 reserveIn, uint256 reserveOut) =
                getReserves(_factory, _path[count], _path[count + 1]);
            MonadexV1Types.Fee memory poolFee = getPoolFee(_factory, _path[count], _path[count + 1]);
            amounts[count + 1] = getAmountOut(amounts[count], reserveIn, reserveOut, poolFee);
        }

        return amounts;
    }

    /**
     * @notice Gets the input amounts at each checkpoint of the swap path
     * @param _factory The factory's address.
     * @param _amountOut The amount of output tokens you desire.
     * @param _path An array of token addresses which forms the swap path in case a direct
     * path does not exist from input token to output token.
     * @return An array which holds the input amounts at each checkpoint of the swap path.
     */
    function getAmountsIn(
        address _factory,
        uint256 _amountOut,
        address[] memory _path
    )
        internal
        view
        returns (uint256[] memory)
    {
        if (_path.length < 2) revert MonadexV1AuxiliaryLibrary__InvalidSwapPath();
        uint256[] memory amounts = new uint256[](_path.length);
        amounts[amounts.length - 1] = _amountOut;

        for (uint256 count = _path.length - 1; count > 0; --count) {
            (uint256 reserveIn, uint256 reserveOut) =
                getReserves(_factory, _path[count - 1], _path[count]);
            MonadexV1Types.Fee memory poolFee = getPoolFee(_factory, _path[count - 1], _path[count]);
            amounts[count - 1] = getAmountIn(amounts[count], reserveIn, reserveOut, poolFee);
        }

        return amounts;
    }

    /**
     * @notice Gets the amount of tickets based on the input token amount and
     * the fee percentage
     * @param _amount The amount of input token.
     * @param _percentage The percentage of the amount to take.
     * @return The amount of tickets.
     */
    function calculateAmountOfTickets(
        uint256 _amount,
        MonadexV1Types.Fee memory _percentage
    )
        internal
        pure
        returns (uint256)
    {
        return (_amount * _percentage.numerator) / _percentage.denominator;
    }
}
