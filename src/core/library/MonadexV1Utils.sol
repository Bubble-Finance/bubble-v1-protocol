// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library MonadexV1Utils {
    /**
     * @notice Sorts tokens such that the token with the smaller address value
     * stands first
     * @param _tokenA Address of token A.
     * @param _tokenB Address of token B.
     * @return A tuple with sorted token addresses.
     */
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
}
