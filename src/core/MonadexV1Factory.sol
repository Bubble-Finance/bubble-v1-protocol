// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { MonadexV1Pool } from "./MonadexV1Pool.sol";
import { IMonadexV1Factory } from "./interfaces/IMonadexV1Factory.sol";
import { IMonadexV1Pool } from "./interfaces/IMonadexV1Pool.sol";
import { MonadexV1Types } from "./library/MonadexV1Types.sol";
import { MonadexV1Utils } from "./library/MonadexV1Utils.sol";
import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";

contract MonadexV1Factory is Ownable, IMonadexV1Factory {
    address private s_protocolTeamMultisig;
    MonadexV1Types.Fee private s_protocolFee;
    MonadexV1Types.Fee[5] private s_feeTiers;

    mapping(address token => bool isSupported) private s_supportedTokens;
    mapping(address tokenA => mapping(address tokenB => uint256 feeTier)) private s_tokenPairToFee;
    mapping(address tokenA => mapping(address tokenB => address pool)) private s_tokenPairToPool;

    event PoolCreated(address indexed pool, address tokenA, address tokenB);
    event ProtocolTeamMultisigChanged(address indexed protocolTeamMultisig);
    event ProtocolFeeChanged(MonadexV1Types.Fee indexed protocolFee);
    event TokenSupportChanged(address indexed token, bool indexed isSupported);
    event FeeTierForTokenPairUpdated(
        address indexed tokenA, address indexed tokenB, uint256 indexed feeTier
    );

    error MonadexV1Factory__NotProtocolTeamMultisig(address sender);
    error MonadexV1Factory__TokenAddressZero();
    error MonadexV1Factory__CannotCreatePoolForSameTokens(address token);
    error MonadexV1Factory__TokenNotSupported(address token);
    error MonadexV1Factory__PoolAlreadyExists(address pool);
    error MonadexV1Factory__InvalidFeeTier(uint256 feeTier);

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
        MonadexV1Pool newPool = new MonadexV1Pool(_tokenA, _tokenB);
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
        emit ProtocolTeamMultisigChanged(_protocolTeamMultisig);
    }

    function setProtocolFee(MonadexV1Types.Fee memory _protocolFee)
        external
        onlyProtocolTeamMultisig
    {
        s_protocolFee = _protocolFee;
        emit ProtocolFeeChanged(_protocolFee);
    }

    function setToken(address _token, bool _isSupported) external onlyOwner {
        s_supportedTokens[_token] = _isSupported;
        emit TokenSupportChanged(_token, _isSupported);
    }

    function setTokenPairFee(
        address _tokenA,
        address _tokenB,
        uint256 _feeTier
    )
        external
        onlyOwner
    {
        if (_feeTier == 0 || _feeTier > 5) revert MonadexV1Factory__InvalidFeeTier(_feeTier);
        (_tokenA, _tokenB) = MonadexV1Utils.sortTokens(_tokenA, _tokenB);
        s_tokenPairToFee[_tokenA][_tokenB] = _feeTier;
        emit FeeTierForTokenPairUpdated(_tokenA, _tokenB, _feeTier);
    }

    function getProtocolTeamMultisig() external view returns (address) {
        return s_protocolTeamMultisig;
    }

    function getProtocolFee() external view returns (MonadexV1Types.Fee memory) {
        return s_protocolFee;
    }

    function getTokenPairToFee(
        address _tokenA,
        address _tokenB
    )
        external
        view
        returns (MonadexV1Types.Fee memory)
    {
        (_tokenA, _tokenB) = MonadexV1Utils.sortTokens(_tokenA, _tokenB);
        uint256 feeTier = s_tokenPairToFee[_tokenA][_tokenB];
        if (feeTier == 0) return s_feeTiers[2];
        else return s_feeTiers[feeTier - 1];
    }

    function getFeeForAllFeeTiers() external view returns (MonadexV1Types.Fee[5] memory) {
        return s_feeTiers;
    }

    function getFeeForTier(uint256 _feeTier) public view returns (MonadexV1Types.Fee memory) {
        if (_feeTier == 0 || _feeTier > 5) revert MonadexV1Factory__InvalidFeeTier(_feeTier);
        return s_feeTiers[_feeTier - 1];
    }

    function isSupportedToken(address _token) public view returns (bool) {
        return s_supportedTokens[_token];
    }

    function getTokenPairToPool(address _tokenA, address _tokenB) public view returns (address) {
        (_tokenA, _tokenB) = MonadexV1Utils.sortTokens(_tokenA, _tokenB);
        return s_tokenPairToPool[_tokenA][_tokenB];
    }
}
