// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract FactoryHelper {
    event MonadexV1Factory__PoolCreated(
        address indexed pool, address indexed tokenA, address indexed tokenB
    );

    error MonadexV1Factory__TokenAddressZero();
    error MonadexV1Factory__CannotCreatePoolForSameTokens(address token);
    error MonadexV1Factory__TokenNotSupported(address token);
    error MonadexV1Factory__PoolAlreadyExists(address pool);
}
