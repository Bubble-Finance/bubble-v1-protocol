// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IMonadexV1Factory } from "../../core/interfaces/IMonadexV1Factory.sol";
import { IMonadexV1Pool } from "../../core/interfaces/IMonadexV1Pool.sol";

import { MonadexV1Types } from "../../core/library/MonadexV1Types.sol";
import { MonadexV1AuxiliaryTypes } from "./MonadexV1AuxiliaryTypes.sol";

library MonadexV1AuxiliaryLibrary {
    error MonadexV1AuxiliaryLibrary__ZeroReserves();
    error MonadexV1AuxiliaryLibrary__ZeroAmountIn();
    error MonadexV1AuxiliaryLibrary__InvalidSwapPath();
    error MonadexV1AuxiliaryLibrary__InputAmountZero();
    error MonadexV1AuxiliaryLibrary__OutputAmountZero();
    error MonadexV1AuxiliaryLibrary__ReservesZero();

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

    function getReserves(
        address _factory,
        address _tokenA,
        address _tokenB
    )
        internal
        view
        returns (uint256, uint256)
    {
        return IMonadexV1Pool(IMonadexV1Factory(_factory).getTokenPairToPool(_tokenA, _tokenB))
            .getReserves();
    }

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
