// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { MonadexV1Pool } from "./MonadexV1Pool.sol";

import { IMonadexV1Factory } from "./interfaces/IMonadexV1Factory.sol";
import { MonadexV1Utils } from "./library/MonadexV1Utils.sol";
import { Ownable, Ownable2Step } from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";

contract MonadexV1Factory is Ownable2Step, IMonadexV1Factory {
    address private s_protocolTeamMultisig;
    uint256 private immutable i_protocolFee;
    uint256 private immutable i_poolFee;
    uint256 private constant FEE_NUMERATOR = 100_000;

    mapping(address token => bool isSupported) private s_supportedTokens;
    mapping(address tokenA => mapping(address tokenB => address pool)) private s_tokenPairToPool;

    event MonadexV1Factory__PoolCreated(
        address indexed pool, address indexed tokenA, address indexed tokenB
    );

    error MonadexV1Factory__TokenAddressZero();
    error MonadexV1Factory__CannotCreatePoolForSameTokens(address token);
    error MonadexV1Factory__TokenNotSupported(address token);
    error MonadexV1Factory__PoolAlreadyExists(address pool);

    constructor(
        address _protocolTeamMultisig,
        uint256 _protocolFee,
        uint256 _poolFee
    )
        Ownable(msg.sender)
    {
        s_protocolTeamMultisig = _protocolTeamMultisig;
        i_protocolFee = _protocolFee;
        i_poolFee = _poolFee;
    }

    function deployPool(address _tokenA, address _tokenB) external returns (address) {
        if (_tokenA == address(0) || _tokenB == address(0)) {
            revert MonadexV1Factory__TokenAddressZero();
        }
        if (_tokenA == _tokenB) revert MonadexV1Factory__CannotCreatePoolForSameTokens(_tokenA);
        if (!isSupportedToken(_tokenA)) revert MonadexV1Factory__TokenNotSupported(_tokenA);
        if (!isSupportedToken(_tokenB)) revert MonadexV1Factory__TokenNotSupported(_tokenB);
        address pool = getTokenPairToPool(_tokenA, _tokenB);
        if (pool != address(0)) revert MonadexV1Factory__PoolAlreadyExists(pool);

        (_tokenA, _tokenB) = MonadexV1Utils.sortTokens(_tokenA, _tokenB);
        MonadexV1Pool newPool = new MonadexV1Pool(_tokenA, _tokenB, i_protocolFee, i_poolFee);
        address newPoolAddress = address(newPool);
        s_tokenPairToPool[_tokenA][_tokenB] = newPoolAddress;

        emit MonadexV1Factory__PoolCreated(newPoolAddress, _tokenA, _tokenB);

        return newPoolAddress;
    }

    function setProtocolTeamMultisigAddress(address _protocolTeamMultisig) external onlyOwner {
        s_protocolTeamMultisig = _protocolTeamMultisig;
    }

    function setToken(address _token, bool _isSupported) external onlyOwner {
        s_supportedTokens[_token] = _isSupported;
    }

    function getProtocolTeamMultisigAddress() external view returns (address) {
        return s_protocolTeamMultisig;
    }

    function getProtocolFee() external view returns (uint256, uint256) {
        return (i_protocolFee, FEE_NUMERATOR);
    }

    function getPoolFee() external view returns (uint256, uint256) {
        return (i_poolFee, FEE_NUMERATOR);
    }

    function isSupportedToken(address _token) public view returns (bool) {
        return s_supportedTokens[_token];
    }

    function getTokenPairToPool(address _tokenA, address _tokenB) public view returns (address) {
        (_tokenA, _tokenB) = MonadexV1Utils.sortTokens(_tokenA, _tokenB);
        return s_tokenPairToPool[_tokenA][_tokenB];
    }
}
