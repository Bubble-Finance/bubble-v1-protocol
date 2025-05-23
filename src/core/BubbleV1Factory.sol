// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";

import { IBubbleV1Factory } from "@src/interfaces/IBubbleV1Factory.sol";
import { IBubbleV1Pool } from "@src/interfaces/IBubbleV1Pool.sol";

import { BubbleV1Pool } from "@src/core/BubbleV1Pool.sol";
import { BubbleV1Library } from "@src/library/BubbleV1Library.sol";
import { BubbleV1Types } from "@src/library/BubbleV1Types.sol";

/// @title BubbleV1Factory.
/// @author Bubble Finance -- mgnfy-view.
/// @notice The factory enables deployment of Bubble pools with different token pairs.
/// The factory also stores the swap fee for each pool, the protocol fee, and the protocol team's
/// multi-sig address.
contract BubbleV1Factory is Ownable, IBubbleV1Factory {
    ///////////////////////
    /// State Variables ///
    ///////////////////////

    /// @dev The maximum numbr of fee tiers available for different pools.
    uint256 private constant MAX_FEE_TIERS = 5;
    /// @dev The default fee tier for each pool.
    uint256 private constant DEFAULT_FEE_TIER = 2;

    /// @dev Initially, the protocol team multi-sig will be the owner of the protocol, and will blacklist some
    /// weird tokens. However, once the ownership is transferred to governance, we do not want the
    /// governance to change the protocol fee recipient and fee value. So it's necessary to track
    /// the team's multisig separately.
    address private s_protocolTeamMultisig;
    /// @dev The cut of the swap fee taken by the protocol team.
    BubbleV1Types.Fraction private s_protocolFee;
    /// @dev Some tokens have weird characteristics and may violate the x * y >= k invariant.
    /// It is necessary to blacklist such tokens.
    mapping(address token => bool isBlacklisted) private s_blacklistedTokens;
    /// @dev Fee tiers range from 1 to 5.
    /// The first tier has the lowest fee, the third tier is the default fee tier
    /// and the 5th tier has the highest fee. The protocol team (in the initial stages, or
    /// governance later on) can set a custom fee tiers for different pools.
    /// Pools with low liquidity or highly volatile assets may be set with higher fee tiers
    /// to compensate liquidity providers for the risk of supplying liquidity to these pools.
    /// Conversely, pools with high liquidity and relatively stable assets may be set with lower fee
    /// tiers since liquidity providers don't take on much risk here.
    /// The default fee tier 3 has the Uniswap v2 fee of 0.3% on each swap.
    /// Fee value for each tier is set during deployment and can't be changed later on.
    BubbleV1Types.Fraction[MAX_FEE_TIERS] private s_feeTiers;
    /// @dev Pools will access data stored in this mapping via a view function to get information
    /// on the fee tier they use.
    mapping(address tokenA => mapping(address tokenB => uint256 feeTier)) private s_tokenPairToFee;
    /// @dev A mapping to track all the deployed pools.
    mapping(address tokenA => mapping(address tokenB => address pool)) private s_tokenPairToPool;
    /// @dev Tracking all deployed pools in an array for utility purposes.
    address[] private s_allPools;

    //////////////
    /// Events ///
    //////////////

    event PoolCreated(address indexed pool, address indexed tokenA, address indexed tokenB);
    event ProtocolTeamMultisigChanged(address indexed protocolTeamMultisig);
    event ProtocolFeeChanged(BubbleV1Types.Fraction indexed protocolFee);
    event TokenSupportChanged(address indexed token, bool indexed isBlacklisted);
    event FeeTierForTokenPairUpdated(
        address indexed tokenA, address indexed tokenB, uint256 indexed feeTier
    );

    //////////////
    /// Errors ///
    //////////////

    error BubbleV1Factory__NotProtocolTeamMultisig(address caller, address protocolTeamMultisig);
    error BubbleV1Factory__AddressZero();
    error BubbleV1Factory__InvalidFeeTier(uint256 invalidFeeTier);
    error BubbleV1Factory__CannotCreatePoolForSameTokens(address token);
    error BubbleV1Factory__TokenNotSupported(address token);
    error BubbleV1Factory__PoolAlreadyExists(address pool);

    /////////////////
    /// Modifiers ///
    /////////////////

    modifier onlyProtocolTeamMultisig() {
        if (msg.sender != s_protocolTeamMultisig) {
            revert BubbleV1Factory__NotProtocolTeamMultisig(msg.sender, s_protocolTeamMultisig);
        }
        _;
    }

    ///////////////////
    /// Constructor ///
    ///////////////////

    /// @notice Sets the protocol team's multisig address, protocol fee, and the fee tiers
    /// during deployment.
    /// @param _protocolTeamMultisig The protocol team's multi-sig address.
    /// @param _protocolFee The protocol's cut of the fee generated in pools.
    /// @param _feeTiers The fee tiers that can be used to customize the fee of each pool.
    constructor(
        address _protocolTeamMultisig,
        BubbleV1Types.Fraction memory _protocolFee,
        BubbleV1Types.Fraction[MAX_FEE_TIERS] memory _feeTiers
    )
        Ownable(msg.sender)
    {
        if (_protocolTeamMultisig == address(0)) revert BubbleV1Factory__AddressZero();
        s_protocolTeamMultisig = _protocolTeamMultisig;
        s_protocolFee = _protocolFee;

        for (uint256 count; count < 5; ++count) {
            if (_feeTiers[count].numerator == 0 || _feeTiers[count].denominator == 0) {
                revert BubbleV1Factory__InvalidFeeTier(count);
            }
            s_feeTiers[count] = _feeTiers[count];
        }
    }

    //////////////////////////
    /// External Functions ///
    //////////////////////////

    /// @notice Allows anyone to deploy Bubble pools for supported tokens. Pools are
    /// deployed using the CREATE2 opcode which allows the frontend to precalculate pool addresses.
    /// Each token pair can have one pool only. The fee for the pool is set in
    /// the factory itself by either the protocol team (in the initial stages), or
    /// governance (later on). The protocol fee is set by the protocol team in the factory contract as
    /// well. Each Bubble pool queries the factory to retrieve information about it's swap fee, the
    /// protocol's cut from the fee, and the protocol team's multisig address.
    /// @param _tokenA The first token in the pair.
    /// @param _tokenB The second token in the pair.
    /// @return The address of the deployed pool.
    function deployPool(address _tokenA, address _tokenB) external returns (address) {
        if (_tokenA == address(0) || _tokenB == address(0)) {
            revert BubbleV1Factory__AddressZero();
        }
        if (_tokenA == _tokenB) revert BubbleV1Factory__CannotCreatePoolForSameTokens(_tokenA);
        if (!isSupportedToken(_tokenA)) revert BubbleV1Factory__TokenNotSupported(_tokenA);
        if (!isSupportedToken(_tokenB)) revert BubbleV1Factory__TokenNotSupported(_tokenB);
        address pool = getTokenPairToPool(_tokenA, _tokenB);
        if (pool != address(0)) {
            revert BubbleV1Factory__PoolAlreadyExists(pool);
        }

        (_tokenA, _tokenB) = BubbleV1Library.sortTokens(_tokenA, _tokenB);
        bytes memory bytecode = type(BubbleV1Pool).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_tokenA, _tokenB));
        uint256 offset = 32;
        address newPoolAddress;
        assembly {
            newPoolAddress := create2(0, add(bytecode, offset), mload(bytecode), salt)
        }
        IBubbleV1Pool(newPoolAddress).initialize(_tokenA, _tokenB);
        // We will not populate the mapping in the reverse direction as all queries to retrieve the
        // pool address should sort the tokens first
        s_tokenPairToPool[_tokenA][_tokenB] = newPoolAddress;
        s_allPools.push(newPoolAddress);

        emit PoolCreated(newPoolAddress, _tokenA, _tokenB);

        return newPoolAddress;
    }

    /// @notice Allows the protocol team to change the address where the protocol's cut of
    /// the swap fee is directed to.
    /// @param _protocolTeamMultisig The new address to direct the protocol's cut of the swap fee to.
    function setProtocolTeamMultisig(
        address _protocolTeamMultisig
    )
        external
        onlyProtocolTeamMultisig
    {
        if (_protocolTeamMultisig == address(0)) revert BubbleV1Factory__AddressZero();

        s_protocolTeamMultisig = _protocolTeamMultisig;

        emit ProtocolTeamMultisigChanged(_protocolTeamMultisig);
    }

    /// @notice Allows the protocol team to set the new protocol's cut of the swap fee. The protocol fee is always
    /// a fraction that is deducted from the swap fee.
    /// @param _protocolFee The new protocol fee.
    function setProtocolFee(
        BubbleV1Types.Fraction memory _protocolFee
    )
        external
        onlyProtocolTeamMultisig
    {
        // Can be set to zero
        s_protocolFee = _protocolFee;

        emit ProtocolFeeChanged(_protocolFee);
    }

    /// @notice Allows the owner (protocol team in the initial stages, governance later on) to blacklist
    /// tokens for trading or remove them from the blacklist.
    /// @param _token The token to support or revoke support from.
    /// @param _isBlacklisted True if blacklisted, false otherwise.
    function setBlackListedToken(address _token, bool _isBlacklisted) external onlyOwner {
        s_blacklistedTokens[_token] = _isBlacklisted;

        emit TokenSupportChanged(_token, _isBlacklisted);
    }

    /// @notice Allows the owner (protocol team in the initial stages, governance later on) to set the
    /// pool's swap fee for any token pair. The fee tiers range from 1 to 5.
    /// @param _tokenA The first token in the pair.
    /// @param _tokenB The second token in the pair.
    /// @param _feeTier The fee tier to set for the token pair.
    function setTokenPairFee(
        address _tokenA,
        address _tokenB,
        uint256 _feeTier
    )
        external
        onlyOwner
    {
        if (!isSupportedToken(_tokenA)) revert BubbleV1Factory__TokenNotSupported(_tokenA);
        if (!isSupportedToken(_tokenB)) revert BubbleV1Factory__TokenNotSupported(_tokenB);
        if (_feeTier == 0 || _feeTier > 5) revert BubbleV1Factory__InvalidFeeTier(_feeTier);

        (_tokenA, _tokenB) = BubbleV1Library.sortTokens(_tokenA, _tokenB);
        s_tokenPairToFee[_tokenA][_tokenB] = _feeTier;

        emit FeeTierForTokenPairUpdated(_tokenA, _tokenB, _feeTier);
    }

    /// @notice Locks a pool in case of an emergency, exploit, or suspicious activity. This will disallow
    /// adding/removing liquidity, and swapping in either direction.
    /// @param _pool The pool to lock.
    function lockPool(address _pool) external onlyOwner {
        IBubbleV1Pool(_pool).lockPool();
    }

    /// @notice Unlocks a pool which was locked under emergency conditions. This will allow
    /// adding/removing liquidity, and swapping in either direction.
    /// @param _pool The pool to lock.
    function unlockPool(address _pool) external onlyOwner {
        IBubbleV1Pool(_pool).unlockPool();
    }

    ///////////////////////////////
    /// View and Pure Functions ///
    ///////////////////////////////

    /// @notice Gets the protocol team's multi-sig address where all the protocol's cut of
    /// the swap fee is directed to.
    /// @return The protocol team's multi-sig address.
    function getProtocolTeamMultisig() external view returns (address) {
        return s_protocolTeamMultisig;
    }

    /// @notice Gets the protocol's cut of the swap fee. Same for all pools.
    /// @return The protocol fee, a struct with numerator and denominator fields.

    function getProtocolFee() external view returns (BubbleV1Types.Fraction memory) {
        return s_protocolFee;
    }

    /// @notice Gets the pool fee for any token pair. If the fee tier isn't set
    /// for that pool, it returns the fee for the default fee tier 3.
    /// @param _tokenA The first token in the pair.
    /// @param _tokenB The second token in the pair.
    /// @return The pool's swap fee, a struct with numerator and denominator fields.
    function getTokenPairToFee(
        address _tokenA,
        address _tokenB
    )
        external
        view
        returns (BubbleV1Types.Fraction memory)
    {
        if (_tokenA == address(0) || _tokenB == address(0)) revert BubbleV1Factory__AddressZero();
        if (!isSupportedToken(_tokenA)) revert BubbleV1Factory__TokenNotSupported(_tokenA);
        if (!isSupportedToken(_tokenB)) revert BubbleV1Factory__TokenNotSupported(_tokenB);

        (_tokenA, _tokenB) = BubbleV1Library.sortTokens(_tokenA, _tokenB);
        uint256 feeTier = s_tokenPairToFee[_tokenA][_tokenB];

        if (feeTier == 0) return s_feeTiers[DEFAULT_FEE_TIER];
        else return s_feeTiers[feeTier - 1];
    }

    /// @notice Gets the fee structs for all fee tiers packed into an array.
    /// @return An array of fee structs for fee tiers 1 to 5.
    function getFeeForAllFeeTiers()
        external
        view
        returns (BubbleV1Types.Fraction[MAX_FEE_TIERS] memory)
    {
        return s_feeTiers;
    }

    /// @notice Gets the fee struct for the specified tier.
    /// @param _feeTier The fee tier to get the fee for. Allowed values are 1 to 5.
    /// @return The pool fee struct with numerator and denominator fields.
    function getFeeForTier(
        uint256 _feeTier
    )
        external
        view
        returns (BubbleV1Types.Fraction memory)
    {
        if (_feeTier == 0 || _feeTier > 5) revert BubbleV1Factory__InvalidFeeTier(_feeTier);

        return s_feeTiers[_feeTier - 1];
    }

    /// @notice Gets an array of addresses of all pools deployed so far. A utility function.
    /// @return An array of all pool addresses.
    function getAllPools() external view returns (address[] memory) {
        return s_allPools;
    }

    /// @notice Pre-calculates the address at which a pool will be deployed to for a given
    /// token pair.
    /// @param _tokenA The first token in the pair.
    /// @param _tokenB The second token in the pair.
    /// @return The pre-calculated pool address.
    function precalculatePoolAddress(
        address _tokenA,
        address _tokenB
    )
        external
        view
        returns (address)
    {
        (_tokenA, _tokenB) = BubbleV1Library.sortTokens(_tokenA, _tokenB);

        bytes32 initCodeHash = keccak256(type(BubbleV1Pool).creationCode);
        address pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            address(this),
                            keccak256(abi.encodePacked(_tokenA, _tokenB)),
                            initCodeHash
                        )
                    )
                )
            )
        );

        return pool;
    }

    /// @notice Gets the pool address from the specified token pair.
    /// @param _tokenA The first token in the pair.
    /// @param _tokenB The second token in the pair.
    /// @return The pool address.
    function getTokenPairToPool(address _tokenA, address _tokenB) public view returns (address) {
        if (_tokenA == address(0) || _tokenB == address(0)) revert BubbleV1Factory__AddressZero();
        if (!isSupportedToken(_tokenA)) revert BubbleV1Factory__TokenNotSupported(_tokenA);
        if (!isSupportedToken(_tokenB)) revert BubbleV1Factory__TokenNotSupported(_tokenB);

        (_tokenA, _tokenB) = BubbleV1Library.sortTokens(_tokenA, _tokenB);

        return s_tokenPairToPool[_tokenA][_tokenB];
    }

    /// @notice Checks if the specified token is supported or not.
    /// @param _token The token to check.
    /// @return True if the token is supported, false otherwise.
    function isSupportedToken(address _token) public view returns (bool) {
        return !s_blacklistedTokens[_token];
    }
}
