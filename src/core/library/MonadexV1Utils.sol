// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { MonadexV1Types } from "./MonadexV1Types.sol";

library MonadexV1Utils {
    function sortTokens(
        address _tokenA,
        address _tokenB
    )
        internal
        pure
        returns (address, address)
    {
        if (_tokenA <= _tokenB) return (_tokenA, _tokenB);
        else return (_tokenB, _tokenA);
    }

    function getProtocolFeeForAmount(
        uint256 _amount,
        uint256 _reserve,
        MonadexV1Types.Fee memory _fee,
        uint256 _totalLpTokenSupply
    )
        internal
        pure
        returns (uint256)
    {
        return (_amount * _fee.numerator * _totalLpTokenSupply) / (_fee.denominator * _reserve);
    }
}
