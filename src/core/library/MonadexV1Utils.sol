// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

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
        uint256 _feeNumerator,
        uint256 _feeDenominator
    )
        internal
        pure
        returns (uint256)
    {
        return (_amount * _feeNumerator) / _feeDenominator;
    }
}
