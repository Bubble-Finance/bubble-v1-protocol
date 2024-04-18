// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { MonadexV1Pool } from "./MonadexV1Pool.sol";
import { IMonadexV1Factory } from "./interfaces/IMonadexV1Factory.sol";
import { IMonadexV1Pool } from "./interfaces/IMonadexV1Pool.sol";
import { MonadexV1Types } from "./library/MonadexV1Types.sol";
import { MonadexV1Utils } from "./library/MonadexV1Utils.sol";
import { Ownable, Ownable2Step } from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";

contract MonadexV1Factory is Ownable2Step, IMonadexV1Factory {
    address private s_protocolTeamMultisig;
    MonadexV1Types.Fee private s_protocolFee;
    MonadexV1Types.Fee[5] private s_feeTiers;

    mapping(address token => bool isSupported) private s_supportedTokens;
    mapping(address tokenA => mapping(address tokenB => MonadexV1Types.Fee fee)) private
        s_tokenPairToFee;
    mapping(address tokenA => mapping(address tokenB => address pool)) private s_tokenPairToPool;

    event PoolCreated(address indexed pool, address indexed tokenA, address indexed tokenB);

    error MonadexV1Factory__TokenAddressZero();
    error MonadexV1Factory__CannotCreatePoolForSameTokens(address token);
    error MonadexV1Factory__TokenNotSupported(address token);
    error MonadexV1Factory__PoolAlreadyExists(address pool);
    error MonadexV1Factory__NotProtocolTeamMultisig(address sender);
    error MonadexV1Factory__InvalidFeeForTokenPair();
    error MonadexV1Factory__PoolFeeAlreadySet(address pool);

    modifier onlyProtocolTeamMultisig() {
        if (msg.sender != s_protocolTeamMultisig) {
            revert MonadexV1Factory__NotProtocolTeamMultisig(msg.sender);
        }
        _;
    }

    constructor(
        address _protocolTeamMultisig,
        MonadexV1Types.Fee memory _protocolFee,
        MonadexV1Types.Fee[5] memory _feeTiers
    )
        Ownable(msg.sender)
    {
        s_protocolTeamMultisig = _protocolTeamMultisig;
        s_protocolFee = _protocolFee;
        for (uint256 count = 0; count < 5; ++count) {
            s_feeTiers[count] = _feeTiers[count];
        }
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
        MonadexV1Types.Fee memory poolFee = s_tokenPairToFee[_tokenA][_tokenB];
        if (poolFee.feeNumerator == 0 || poolFee.feeDenominator == 0) {
            revert MonadexV1Factory__InvalidFeeForTokenPair();
        }
        MonadexV1Pool newPool =
            new MonadexV1Pool(_tokenA, _tokenB, s_protocolFee, poolFee, s_protocolTeamMultisig);
        address newPoolAddress = address(newPool);
        s_tokenPairToPool[_tokenA][_tokenB] = newPoolAddress;

        emit PoolCreated(newPoolAddress, _tokenA, _tokenB);

        return newPoolAddress;
    }

    function setProtocolTeamMultisig(address _protocolTeamMultisig)
        external
        onlyProtocolTeamMultisig
    {
        s_protocolTeamMultisig = _protocolTeamMultisig;
    }

    function syncPoolsProtocolTeamMultisig(address _pool) external onlyProtocolTeamMultisig {
        IMonadexV1Pool(_pool).setProtocolTeamMultisig(s_protocolTeamMultisig);
    }

    function setProtocolFee(MonadexV1Types.Fee memory _protocolFee)
        external
        onlyProtocolTeamMultisig
    {
        s_protocolFee = _protocolFee;
    }

    function syncPoolsProtocolFee(address _pool) external onlyProtocolTeamMultisig {
        IMonadexV1Pool(_pool).setProtocolFee(s_protocolFee);
    }

    function setToken(address _token, bool _isSupported) external onlyOwner {
        s_supportedTokens[_token] = _isSupported;
    }

    function setTokenPairFee(
        address _tokenA,
        address _tokenB,
        uint256 _feeTier
    )
        external
        onlyOwner
    {
        (_tokenA, _tokenB) = MonadexV1Utils.sortTokens(_tokenA, _tokenB);
        address pool = getTokenPairToPool(_tokenA, _tokenB);
        if (pool != address(0)) revert MonadexV1Factory__PoolFeeAlreadySet(pool);
        s_tokenPairToFee[_tokenA][_tokenB] = s_feeTiers[_feeTier];
    }

    function getProtocolTeamMultisig() external view returns (address) {
        return s_protocolTeamMultisig;
    }

    function getAllFeeTiers() external view returns (MonadexV1Types.Fee[5] memory) {
        return s_feeTiers;
    }

    function isSupportedToken(address _token) public view returns (bool) {
        return s_supportedTokens[_token];
    }

    function getTokenPairToPool(address _tokenA, address _tokenB) public view returns (address) {
        (_tokenA, _tokenB) = MonadexV1Utils.sortTokens(_tokenA, _tokenB);
        return s_tokenPairToPool[_tokenA][_tokenB];
    }

    function getFeeTier(uint256 _tier) public view returns (MonadexV1Types.Fee memory) {
        return s_feeTiers[_tier];
    }
}
