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
pragma solidity 0.8.24;

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from
    "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

import { ERC20 } from "@solmate/tokens/ERC20.sol";

import { IMonadexV1Callee } from "../interfaces/IMonadexV1Callee.sol";
import { IMonadexV1Factory } from "../interfaces/IMonadexV1Factory.sol";
import { IMonadexV1Pool } from "../interfaces/IMonadexV1Pool.sol";

import { MonadexV1Library } from "../library/MonadexV1Library.sol";
import { MonadexV1Types } from "../library/MonadexV1Types.sol";

/// @title MonadexV1Pool.
/// @author Monadex Labs -- mgnfy-view.
/// @notice Monadex pools store reserves of a token pair, and allow supplying liquidity,
/// withdrawing liquidity, and swapping tokens in either direction.
contract MonadexV1Pool is ERC20, IMonadexV1Pool {
    using SafeERC20 for IERC20;
    using Math for uint256;

    ///////////////////////
    /// State Variables ///
    ///////////////////////

    uint256 constant MINIMUM_LIQUIDITY = 1_000;
    address private immutable i_factory;
    address private s_tokenA;
    address private s_tokenB;
    uint256 private s_reserveA;
    uint256 private s_reserveB;
    /// @dev The last constant K value, used to calculate the protocol's cut of the total
    /// fees generated during swaps.
    uint256 private s_lastK;
    /// @dev A global lock to ensure no re-entrancy issues occur.
    bool private s_isLocked;

    //////////////
    /// Events ///
    //////////////

    event Initialised(address indexed tokenA, address indexed tokenB);
    event LiquidityAdded(
        address indexed by,
        address indexed receiver,
        uint256 amountA,
        uint256 amountB,
        uint256 indexed lpTokensMinted
    );
    event LiquidityRemoved(
        address indexed by,
        address indexed receiver,
        uint256 amountA,
        uint256 amountB,
        uint256 indexed lpTokensBurned
    );
    event AmountSwapped(
        address indexed caller,
        uint256 amountAIn,
        uint256 amountBIn,
        uint256 amountAOut,
        uint256 amountBOut,
        address indexed _receiver
    );
    event PoolLocked();
    event PoolUnlocked();
    event ReservesUpdated(uint256 indexed reserveA, uint256 indexed reserveB);

    //////////////
    /// Errors ///
    //////////////

    error MonadexV1Factory__AlreadyInitialised();
    error MonadexV1Pool__Locked();
    error MonadexV1Pool__NotFactory();
    error MonadexV1Pool__ZeroLpTokensToMint();
    error MonadexV1Pool__CannotWithdrawZeroTokenAmount();
    error MonadexV1Pool__InsufficientOutputAmount();
    error MonadexV1Pool__OutputAmountGreaterThanReserves();
    error MonadexV1Pool__InvalidReceiver(address receiver);
    error MonadexV1Pool__InsufficientInputAmount();
    error MonadexV1Pool__InvalidK();

    /////////////////
    /// Modifiers ///
    /////////////////

    modifier globalLock() {
        if (s_isLocked) revert MonadexV1Pool__Locked();
        s_isLocked = true;
        _;
        s_isLocked = false;
    }

    modifier onlyFactory() {
        if (msg.sender != i_factory) revert MonadexV1Pool__NotFactory();
        _;
    }

    ///////////////////
    /// Constructor ///
    ///////////////////

    /// @notice Sets the factory address as well as the name for EIP712 signatures.
    constructor() ERC20("MonadexLPToken", "MDXLP", 18) {
        i_factory = msg.sender;
    }

    //////////////////////////
    /// External Functions ///
    //////////////////////////

    /// @notice This function is called by the Monadex V1 factory right after pool deployment
    /// to set the token addresses for this pool.
    /// @param _tokenA Address of the first token in the pair.
    /// @param _tokenB Address of the second token in the pair.
    function initialize(address _tokenA, address _tokenB) external onlyFactory {
        if (s_tokenA != address(0) && s_tokenB != address(0)) {
            revert MonadexV1Factory__AlreadyInitialised();
        }

        s_tokenA = _tokenA;
        s_tokenB = _tokenB;

        emit Initialised(_tokenA, _tokenB);
    }

    /// @notice Allows liquidity providers to add liquidity to the pool, and get LP tokens which
    /// represent their share of the pool. The protocol team is minted their share of the swap fee
    /// accumulated in the pool before proceeding to add liquidity. It is recommended to use the
    /// Monadex v1 router (which performs additional safety checks) for this action.
    /// @param _receiver The address to send the LP tokens to.
    /// @return The amount of LP tokens minted.
    function addLiquidity(address _receiver) external globalLock returns (uint256) {
        (uint256 reserveA, uint256 reserveB) = getReserves();
        uint256 balanceA = IERC20(s_tokenA).balanceOf(address(this));
        uint256 balanceB = IERC20(s_tokenB).balanceOf(address(this));
        uint256 amountAIn = balanceA - reserveA;
        uint256 amountBIn = balanceB - reserveB;
        uint256 lpTokensToMint;

        _mintProtocolFee(reserveA, reserveB);
        uint256 totalLpTokenSupply = totalSupply;
        if (totalLpTokenSupply == 0) {
            lpTokensToMint = (amountAIn * amountBIn).sqrt() - MINIMUM_LIQUIDITY;
            _mint(address(1), MINIMUM_LIQUIDITY);
        } else {
            lpTokensToMint = ((amountAIn * totalLpTokenSupply) / reserveA).min(
                (amountBIn * totalLpTokenSupply) / reserveB
            );
        }
        if (lpTokensToMint == 0) revert MonadexV1Pool__ZeroLpTokensToMint();
        _mint(_receiver, lpTokensToMint);
        _updateReserves(balanceA, balanceB);
        s_lastK = s_reserveA * s_reserveB;

        emit LiquidityAdded(msg.sender, _receiver, amountAIn, amountBIn, lpTokensToMint);

        return lpTokensToMint;
    }

    /// @notice Allows liquidity providers to exit their positions by withdrawing their liquidity
    /// based on their share of the pool. The protocol team is minted their share of the fee
    /// accumulated in the pool before proceeding to remove liquidity. It is recommended to use the
    /// Monadex v1 router (which performs additional safety checks) for this action.
    /// @param _receiver The address to direct the withdrawn liquidity to.
    /// @return Amount of token A withdrawn.
    /// @return Amount of token B withdrawn.
    function removeLiquidity(address _receiver) external globalLock returns (uint256, uint256) {
        (uint256 reserveA, uint256 reserveB) = getReserves();
        uint256 balanceA = IERC20(s_tokenA).balanceOf(address(this));
        uint256 balanceB = IERC20(s_tokenB).balanceOf(address(this));
        uint256 lpTokensReceived = balanceOf[address(this)];

        _mintProtocolFee(reserveA, reserveB);
        uint256 totalLpTokenSupply = totalSupply;
        uint256 amountAOut = (lpTokensReceived * balanceA) / totalLpTokenSupply;
        uint256 amountBOut = (lpTokensReceived * balanceB) / totalLpTokenSupply;
        if (amountAOut == 0 || amountBOut == 0) {
            revert MonadexV1Pool__CannotWithdrawZeroTokenAmount();
        }
        _burn(address(this), lpTokensReceived);
        IERC20(s_tokenA).safeTransfer(_receiver, amountAOut);
        IERC20(s_tokenB).safeTransfer(_receiver, amountBOut);
        balanceA = IERC20(s_tokenA).balanceOf(address(this));
        balanceB = IERC20(s_tokenB).balanceOf(address(this));
        _updateReserves(balanceA, balanceB);
        s_lastK = s_reserveA * s_reserveB;

        emit LiquidityRemoved(msg.sender, _receiver, amountAOut, amountBOut, lpTokensReceived);

        return (amountAOut, amountBOut);
    }

    /// @notice Allows swapping of tokens in either direction. Also allows flash swaps and
    /// flash loans, all packed in the same function. Additionally, users leveraging flash
    /// swaps and flash loans can invoke hooks before and after a swap.
    /// @param _swapParams The parameters for swapping.
    function swap(MonadexV1Types.SwapParams memory _swapParams) external globalLock {
        if (_swapParams.amountAOut == 0 && _swapParams.amountBOut == 0) {
            revert MonadexV1Pool__InsufficientOutputAmount();
        }
        (uint256 reserveA, uint256 reserveB) = getReserves();
        if (_swapParams.amountAOut >= reserveA || _swapParams.amountBOut >= reserveB) {
            revert MonadexV1Pool__OutputAmountGreaterThanReserves();
        }

        uint256 balanceA;
        uint256 balanceB;
        {
            if (_swapParams.receiver == s_tokenA || _swapParams.receiver == s_tokenB) {
                revert MonadexV1Pool__InvalidReceiver(_swapParams.receiver);
            }
            if (_swapParams.hookConfig.hookBeforeCall) {
                IMonadexV1Callee(_swapParams.receiver).hookBeforeCall(
                    msg.sender, _swapParams.amountAOut, _swapParams.amountBOut, _swapParams.data
                );
            }
            if (_swapParams.amountAOut > 0) {
                IERC20(s_tokenA).safeTransfer(_swapParams.receiver, _swapParams.amountAOut);
            }
            if (_swapParams.amountBOut > 0) {
                IERC20(s_tokenB).safeTransfer(_swapParams.receiver, _swapParams.amountBOut);
            }
            if (_swapParams.data.length > 0) {
                IMonadexV1Callee(_swapParams.receiver).onCall(
                    msg.sender, _swapParams.amountAOut, _swapParams.amountBOut, _swapParams.data
                );
            }
            balanceA = IERC20(s_tokenA).balanceOf(address(this));
            balanceB = IERC20(s_tokenB).balanceOf(address(this));
        }
        uint256 amountAIn = balanceA > reserveA - _swapParams.amountAOut
            ? balanceA - (reserveA - _swapParams.amountAOut)
            : 0;
        uint256 amountBIn = balanceB > reserveB - _swapParams.amountBOut
            ? balanceB - (reserveB - _swapParams.amountBOut)
            : 0;
        if (amountAIn == 0 && amountBIn == 0) revert MonadexV1Pool__InsufficientInputAmount();
        {
            MonadexV1Types.Fraction memory poolFee = getPoolFee();
            uint256 balanceAAdjusted =
                (balanceA * poolFee.denominator) - (amountAIn * poolFee.numerator);
            uint256 balanceBAdjusted =
                (balanceB * poolFee.denominator) - (amountBIn * poolFee.numerator);
            if (
                balanceAAdjusted * balanceBAdjusted
                    < reserveA * reserveB * (poolFee.denominator ** 2)
            ) {
                revert MonadexV1Pool__InvalidK();
            }
        }
        _updateReserves(balanceA, balanceB);

        emit AmountSwapped(
            msg.sender,
            amountAIn,
            amountBIn,
            _swapParams.amountAOut,
            _swapParams.amountBOut,
            _swapParams.receiver
        );

        if (_swapParams.hookConfig.hookAfterCall) {
            IMonadexV1Callee(_swapParams.receiver).hookAfterCall(
                msg.sender, _swapParams.amountAOut, _swapParams.amountBOut, _swapParams.data
            );
        }
    }

    /// @notice Allows anyone to sync the balances held by the contract with the currently
    /// tracked token reserves by removing the excess amounts.
    /// @param _receiver The address to direct the excess amounts to.
    function syncBalancesBasedOnReserves(address _receiver) external globalLock {
        (address tokenA, address tokenB) = getPoolTokens();

        IERC20(tokenA).safeTransfer(_receiver, IERC20(tokenA).balanceOf(address(this)) - s_reserveA);
        IERC20(tokenB).safeTransfer(_receiver, IERC20(tokenB).balanceOf(address(this)) - s_reserveB);
    }

    /// @notice Allows anyone to sync the currently tracked token reserves with the actual token
    /// balances held by the contract by setting the reserve values to the actual token balances
    /// held by the pool.
    function syncReservesBasedOnBalances() external globalLock {
        _updateReserves(
            IERC20(s_tokenA).balanceOf(address(this)), IERC20(s_tokenB).balanceOf(address(this))
        );
    }

    /// @notice Locks the pool in case of an emergency, exploit, or suspicious activity.
    function lockPool() external onlyFactory {
        s_isLocked = true;

        emit PoolLocked();
    }

    /// @notice Unlocks the pool after it was locked under emergency conditions.
    function unlockPool() external onlyFactory {
        s_isLocked = false;

        emit PoolUnlocked();
    }

    //////////////////////////
    /// Internal Functions ///
    //////////////////////////

    /// @notice Updates the reserves after each swap, liquidity addition or removal action.
    /// @param _reserveA Token A's reserve.
    /// @param _reserveB Token B's reserve.
    function _updateReserves(uint256 _reserveA, uint256 _reserveB) internal {
        s_reserveA = _reserveA;
        s_reserveB = _reserveB;

        emit ReservesUpdated(_reserveA, _reserveB);
    }

    /// @notice Mint's the protocol's cut of the swap fee to the protocol team's multi-sig address.
    /// @param _reserveA Token A's reserve.
    /// @param _reserveB Token B's reserve.
    function _mintProtocolFee(uint256 _reserveA, uint256 _reserveB) internal {
        address protocolTeamMultisig = getProtocolTeamMultisig();
        MonadexV1Types.Fraction memory protocolFee = getProtocolFee();
        uint256 lastK = s_lastK;
        uint256 totalLpTokenSupply = totalSupply;

        if (lastK != 0) {
            uint256 rootK = (_reserveA * _reserveB).sqrt();
            uint256 rootKLast = lastK.sqrt();
            if (rootK > rootKLast) {
                uint256 numerator =
                    (totalLpTokenSupply * (rootK - rootKLast) * protocolFee.numerator);
                uint256 denominator = (rootK * protocolFee.denominator)
                    - (rootK * protocolFee.numerator) + (rootKLast * protocolFee.numerator);
                uint256 lpTokensToMint = numerator / denominator;
                if (lpTokensToMint > 0) _mint(protocolTeamMultisig, lpTokensToMint);
            }
        }
    }

    ///////////////////////////////
    /// View and Pure Functions ///
    ///////////////////////////////

    /// @notice Checks if the specified token is one of the tokens in the pool.
    /// @param _token The token address.
    /// @return True if the token is a pool token, false otherwise.
    function isPoolToken(address _token) external view returns (bool) {
        if (_token != s_tokenA || _token != s_tokenB) return false;
        return true;
    }

    /// @notice Gets the address of the MonadexV1Factory.
    /// @return The factory address.
    function getFactory() external view returns (address) {
        return i_factory;
    }

    /// @notice Gets the protocol team's multi-sig address from the factory. Used to direct
    /// part of the swap fee to the protocol team.
    /// @return The protocol team's multi-sig address.
    function getProtocolTeamMultisig() public view returns (address) {
        return IMonadexV1Factory(i_factory).getProtocolTeamMultisig();
    }

    /// @notice Gets the protocol's cut of the swap fee from the factory.
    /// @return The protocol fee, a struct with numerator and denominator fields.
    function getProtocolFee() public view returns (MonadexV1Types.Fraction memory) {
        return IMonadexV1Factory(i_factory).getProtocolFee();
    }

    /// @notice Gets the swap fee from the factory.
    /// @return The swap fee, a struct with numerator and denominator fields.
    function getPoolFee() public view returns (MonadexV1Types.Fraction memory) {
        return IMonadexV1Factory(i_factory).getTokenPairToFee(s_tokenA, s_tokenB);
    }

    /// @notice Gets the addresses of the tokens in this pool.
    /// @return The first token's address.
    /// @return The second token's address.
    function getPoolTokens() public view returns (address, address) {
        return (s_tokenA, s_tokenB);
    }

    /// @notice Gets the reserves of both tokens in the pool.
    /// @return Token A's reserve.
    /// @return Token B's reserve.
    function getReserves() public view returns (uint256, uint256) {
        return (s_reserveA, s_reserveB);
    }
}
