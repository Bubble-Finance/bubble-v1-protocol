// Layout:
//     - pragma
//     - imports
//     - interfaces, libraries, contracts
//     - type declarations
//     - state variables
//     - events
//     - errors
//     - modifiers
//     - functions
//         - constructor
//         - receive function (if exists)
//         - fallback function (if exists)
//         - external
//         - public
//         - internal
//         - private
//         - view and pure functions

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";

import { IMonadexV1Factory } from "../interfaces/IMonadexV1Factory.sol";
import { IMonadexV1Pool } from "../interfaces/IMonadexV1Pool.sol";

import { MonadexV1Library } from "../library/MonadexV1Library.sol";
import { MonadexV1Types } from "../library/MonadexV1Types.sol";
import { MonadexV1Pool } from "./MonadexV1Pool.sol";

/**
 * @title MonadexV1Factory.
 * @author Monadex Labs -- mgnfy-view.
 * @notice The factory allows deployment of Monadex pools with different token combinations.
 * The factory also stores the fee for each pool, the protocol fee, and the protocol team's
 * multisig address.
 */
contract MonadexV1Factory is IMonadexV1Factory, Ownable {
    ///////////////////////
    /// State Variables ///
    ///////////////////////

    // Initially, the protocol team will be the owner of the protocol, and will support tokens
    // for trading. However, once the ownership is transferred to governance, we do not want the
    // governance to change the protocol fee recipient and fee value. So it's necessary to track
    // the team's multisig separately
    address private s_protocolTeamMultisig;
    MonadexV1Types.Fee private s_protocolFee;
    mapping(address token => bool isSupported) private s_supportedTokens;
    // fee tiers range from 1 to 5
    // The first tier has the lowest fee, the third tier is the default fee tier
    // and the 5th tier has the highest fee. The protocol team (in the initial stages, or
    // governance later on) can set a custom fee tier for different pools
    // pools with low liquidity or highly volatile assets may be set with higher fee tiers
    // to compensate liquidity providers for the risk of supplying liquidity to these pools
    // Coversely, pools with high liquidity and relatively stable assets may be set with lower fee
    // tiers since liquidity providers don't take on much risk
    // the default fee tier 3 has the Uniswap v2 fee of 0.3% on each swap
    // fee value for each tier is set during deployment and can't be changed later on
    MonadexV1Types.Fee[5] private s_feeTiers;
    // pools will access data stored in this mapping via a view function to get information
    // on the fee tier they use
    mapping(address tokenA => mapping(address tokenB => uint256 feeTier)) private s_tokenPairToFee;
    // tokens must be sorted before a pool is searched for them
    // this saves space
    mapping(address tokenA => mapping(address tokenB => address pool)) private s_tokenPairToPool;

    //////////////
    /// Events ///
    //////////////

    event PoolCreated(address indexed pool, address tokenA, address tokenB);
    event ProtocolTeamMultisigChanged(address indexed protocolTeamMultisig);
    event ProtocolFeeChanged(MonadexV1Types.Fee indexed protocolFee);
    event TokenSupportChanged(address indexed token, bool indexed isSupported);
    event FeeTierForTokenPairUpdated(
        address indexed tokenA, address indexed tokenB, uint256 indexed feeTier
    );

    //////////////
    /// Errors ///
    //////////////

    error MonadexV1Factory__NotProtocolTeamMultisig(address sender);
    error MonadexV1Factory__TokenAddressZero();
    error MonadexV1Factory__CannotCreatePoolForSameTokens();
    error MonadexV1Factory__TokenNotSupported(address token);
    error MonadexV1Factory__PoolAlreadyExists(address pool);
    error MonadexV1Factory__InvalidFeeTier();

    /////////////////
    /// Modifiers ///
    /////////////////

    modifier onlyProtocolTeamMultisig() {
        if (msg.sender != s_protocolTeamMultisig) {
            revert MonadexV1Factory__NotProtocolTeamMultisig(msg.sender);
        }
        _;
    }

    ///////////////////
    /// Constructor ///
    ///////////////////

    /**
     * @notice Sets the protocol team's multisig address, protocol fee, and the fee tiers
     * during deployment.
     * @param _protocolTeamMultisig The protocol team's multisig address.
     * @param _protocolFee The protocol's cut of the fee generated in pools.
     * @param _feeTiers The fee tiers that can be used to customize the fee of each pool.
     */
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

    //////////////////////////
    /// External Functions ///
    //////////////////////////

    /**
     * @notice Allows anyone to deploy Monadex pools for supported token combinations
     * Each token combination can have one pool only. The fee for the pool is set in
     * the factory itself by either the protocol team (in the initial stages), or
     * governance. The protocol fee is set by the protocol team in the factory contract as
     * well. Each Monadex pool queries the factory to retrieve information about it's fee, the
     * protocol fee, and the protocol team's multisig address.
     * @param _tokenA The first token in the combination.
     * @param _tokenB The second token in the combination.
     * @return The address of the deployed pool.
     */
    function deployPool(address _tokenA, address _tokenB) external returns (address) {
        if (_tokenA == address(0) || _tokenB == address(0)) {
            revert MonadexV1Factory__TokenAddressZero();
        }
        if (_tokenA == _tokenB) revert MonadexV1Factory__CannotCreatePoolForSameTokens();
        if (!isSupportedToken(_tokenA)) revert MonadexV1Factory__TokenNotSupported(_tokenA);
        if (!isSupportedToken(_tokenB)) revert MonadexV1Factory__TokenNotSupported(_tokenB);
        address pool = getTokenPairToPool(_tokenA, _tokenB);
        if (pool != address(0)) revert MonadexV1Factory__PoolAlreadyExists(pool);

        (_tokenA, _tokenB) = MonadexV1Library.sortTokens(_tokenA, _tokenB);
        MonadexV1Pool newPool = new MonadexV1Pool(_tokenA, _tokenB);
        address newPoolAddress = address(newPool);
        s_tokenPairToPool[_tokenA][_tokenB] = newPoolAddress;

        emit PoolCreated(newPoolAddress, _tokenA, _tokenB);

        return newPoolAddress;
    }

    /**
     * @notice Allows the protocol team to change the address where all the fee is directed to.
     * @param _protocolTeamMultisig The new address to direct the protocol fee to.
     */
    function setProtocolTeamMultisig(address _protocolTeamMultisig)
        external
        onlyProtocolTeamMultisig
    {
        s_protocolTeamMultisig = _protocolTeamMultisig;

        emit ProtocolTeamMultisigChanged(_protocolTeamMultisig);
    }

    /**
     * @notice Allows the protocol team to set the new protocol fee. The protocol fee is always
     * a fraction that is deducted from the pool fee.
     * @param _protocolFee The new protocol fee.
     */
    function setProtocolFee(MonadexV1Types.Fee memory _protocolFee)
        external
        onlyProtocolTeamMultisig
    {
        s_protocolFee = _protocolFee;

        emit ProtocolFeeChanged(_protocolFee);
    }

    /**
     * @notice Allows the owner (protocol team in the initial stages, governance later on) to support
     * new tokens for trading or revoke support from existing tokens. It should be ensured that the token
     * is not a weird ERC20.
     * @param _token The token to support or revoke support from.
     * @param _isSupported true if supported, false otherwise.
     */
    function setToken(address _token, bool _isSupported) external onlyOwner {
        s_supportedTokens[_token] = _isSupported;

        emit TokenSupportChanged(_token, _isSupported);
    }

    /**
     * @notice Allows the owner (protocol team in the initial stages, governance later on) to set the
     * pool fee for any token combination. The fee tiers range from 1 to 5.
     * @param _tokenA The first token in the combination.
     * @param _tokenB The second token in the combination.
     * @param _feeTier The fee tier to set for the token combination.
     */
    function setTokenPairFee(
        address _tokenA,
        address _tokenB,
        uint256 _feeTier
    )
        external
        onlyOwner
    {
        if (_feeTier == 0 || _feeTier > 5) revert MonadexV1Factory__InvalidFeeTier();

        (_tokenA, _tokenB) = MonadexV1Library.sortTokens(_tokenA, _tokenB);
        s_tokenPairToFee[_tokenA][_tokenB] = _feeTier;

        emit FeeTierForTokenPairUpdated(_tokenA, _tokenB, _feeTier);
    }

    /**
     * @notice Locks a pool in case of an emergency, exploit, or suspicious activity.
     * @param _pool The pool to lock.
     */
    function lockPool(address _pool) external onlyProtocolTeamMultisig {
        IMonadexV1Pool(_pool).lockPool();
    }

    /**
     * @notice Unlocks a pool which was locked under emergency conditions.
     * @param _pool The pool to lock.
     */
    function unlockPool(address _pool) external onlyProtocolTeamMultisig {
        IMonadexV1Pool(_pool).unlockPool();
    }

    /**
     * @notice Gets the protocol team's multi-sig address where all the fee is directed to.
     * @return The protocol team's multi-sig address.
     */
    function getProtocolTeamMultisig() external view returns (address) {
        return s_protocolTeamMultisig;
    }

    /**
     * @notice Gets the protocol fee. Same for all pools.
     * @return The protocol fee, a struct with numerator and denominator fields.
     */
    function getProtocolFee() external view returns (MonadexV1Types.Fee memory) {
        return s_protocolFee;
    }

    /**
     * @notice Gets the pool fee for any token pair. If the fee tier isn't set
     * for that pool, it returns the fee for the default fee tier 3.
     * @param _tokenA The first token in the combination.
     * @param _tokenB The second token in the combination.
     * @return The pool fee, a struct with numerator and denominator fields.
     */
    function getTokenPairToFee(
        address _tokenA,
        address _tokenB
    )
        external
        view
        returns (MonadexV1Types.Fee memory)
    {
        (_tokenA, _tokenB) = MonadexV1Library.sortTokens(_tokenA, _tokenB);
        uint256 feeTier = s_tokenPairToFee[_tokenA][_tokenB];

        if (feeTier == 0) return s_feeTiers[2];
        else return s_feeTiers[feeTier - 1];
    }

    /**
     * @notice Gets fee structs for all fee tiers packed into an array.
     * @return An array of fee structs for fee tiers 1 to 5.
     */
    function getFeeForAllFeeTiers() external view returns (MonadexV1Types.Fee[5] memory) {
        return s_feeTiers;
    }

    /**
     * @notice Gets the fee struct for the specified tier.
     * @param _feeTier The fee tier to get the fee for. Allowed values are 1 to 5.
     * @return The pool fee struct with numerator and denominator fields.
     */
    function getFeeForTier(uint256 _feeTier) external view returns (MonadexV1Types.Fee memory) {
        if (_feeTier == 0 || _feeTier > 5) revert MonadexV1Factory__InvalidFeeTier();

        return s_feeTiers[_feeTier - 1];
    }

    ////////////////////////
    /// Public Functions ///
    ////////////////////////

    /**
     * @notice Checks if the specified token is supported or not.
     * @param _token The token to check.
     * @return True if the token is supported, false otherwise.
     */
    function isSupportedToken(address _token) public view returns (bool) {
        return s_supportedTokens[_token];
    }

    /**
     * @notice Gets the pool address from the specified token combination. Returns
     * address 0 if no pool exists.
     * @param _tokenA The first token in the combination.
     * @param _tokenB The second token in the combination.
     * @return The pool address.
     */
    function getTokenPairToPool(address _tokenA, address _tokenB) public view returns (address) {
        (_tokenA, _tokenB) = MonadexV1Library.sortTokens(_tokenA, _tokenB);

        return s_tokenPairToPool[_tokenA][_tokenB];
    }
}
