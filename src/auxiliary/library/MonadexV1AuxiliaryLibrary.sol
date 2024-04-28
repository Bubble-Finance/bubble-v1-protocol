// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IMonadexV1Factory } from "../../core/interfaces/IMonadexV1Factory.sol";
import { IMonadexV1Pool } from "../../core/interfaces/IMonadexV1Pool.sol";
import { MonadexV1AuxiliaryTypes } from "./MonadexV1AuxiliaryTypes.sol";

library MonadexV1AuxiliaryLibrary {
    error MonadexV1AuxiliaryLibrary__ZeroReserves();
    error MonadexV1AuxiliaryLibrary__ZeroAmountIn();

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
}
