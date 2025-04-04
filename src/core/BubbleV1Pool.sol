// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";

import { IBubbleV1Callee } from "@src/interfaces/IBubbleV1Callee.sol";
import { IBubbleV1Factory } from "@src/interfaces/IBubbleV1Factory.sol";
import { IBubbleV1Pool } from "@src/interfaces/IBubbleV1Pool.sol";
import { BubbleV1Library } from "@src/library/BubbleV1Library.sol";
import { BubbleV1Types } from "@src/library/BubbleV1Types.sol";

/// @title BubbleV1Pool.
/// @author Bubble Finance -- mgnfy-view.
/// @notice Bubble pools store reserves of a token pair, and allow supplying liquidity,
/// withdrawing liquidity, and swapping tokens in either direction.
contract BubbleV1Pool is ERC20, IBubbleV1Pool {
    using SafeERC20 for IERC20;
    using Math for uint256;

    ///////////////////////
    /// State Variables ///
    ///////////////////////

    /// @dev Minimum LP tokens minted to dead address to prevent inflation attacks.
    uint256 private constant MINIMUM_LIQUIDITY = 1_000;
    /// @dev The LP token decimals.
    uint8 private constant DECIMALS = 18;

    /// @dev Address of the factory that deployed this pool.
    address private immutable i_factory;
    /// @dev The first token in the pool.
    address private s_tokenA;
    /// @dev The second token in the pool.
    address private s_tokenB;
    /// @dev The reserves of the first token in the pool.
    uint256 private s_reserveA;
    /// @dev The reserves of the second token in the pool.
    uint256 private s_reserveB;
    /// @dev The last constant K value, used to calculate the protocol's cut of the total
    /// fees generated during swaps.
    uint256 private s_lastK;
    /// @dev A global lock to ensure no re-entrancy issues occur.
    bool private s_isLocked;

    /// @dev The timestamp when the TWAP was last updated.
    uint32 private s_blockTimestampLast;
    /// @dev The TWAP of the first token in the pool.
    uint256 private s_priceACumulativeLast;
    /// @dev The TWAP of the second token in the pool.
    uint256 private s_priceBCumulativeLast;

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

    error BubbleV1Pool__Locked();
    error BubbleV1Pool__NotFactory();
    error BubbleV1Pool__ZeroLpTokensToMint();
    error BubbleV1Pool__CannotWithdrawZeroTokenAmount();
    error BubbleV1Pool__InsufficientOutputAmount();
    error BubbleV1Pool__OutputAmountGreaterThanReserves();
    error BubbleV1Pool__InvalidReceiver(address receiver);
    error BubbleV1Pool__InsufficientInputAmount();
    error BubbleV1Pool__InvalidK();
    error BubbleV1Pool__BalancesOverflow();

    /////////////////
    /// Modifiers ///
    /////////////////

    modifier globalLock() {
        if (s_isLocked) revert BubbleV1Pool__Locked();
        s_isLocked = true;
        _;
        s_isLocked = false;
    }

    modifier onlyFactory() {
        if (msg.sender != i_factory) revert BubbleV1Pool__NotFactory();
        _;
    }

    ///////////////////
    /// Constructor ///
    ///////////////////

    /// @notice Sets the factory address, and the temporary LP token metadata.
    constructor() ERC20("", "", DECIMALS) {
        i_factory = msg.sender;
    }

    //////////////////////////
    /// External Functions ///
    //////////////////////////

    /// @notice This function is called by the Bubble V1 factory right after pool deployment
    /// to set the token addresses for this pool, as well as the LP token name and symbol.
    /// @param _tokenA Address of the first token in the pair.
    /// @param _tokenB Address of the second token in the pair.
    function initialize(address _tokenA, address _tokenB) external onlyFactory {
        s_tokenA = _tokenA;
        s_tokenB = _tokenB;

        name = string.concat(
            "Bubble ",
            IERC20Metadata(_tokenA).name(),
            " ",
            IERC20Metadata(_tokenB).name(),
            " LP Token"
        );
        symbol =
            string.concat("mdx", IERC20Metadata(_tokenA).symbol(), IERC20Metadata(_tokenB).symbol());

        emit Initialised(_tokenA, _tokenB);
    }

    /// @notice Allows liquidity providers to add liquidity to the pool, and get LP tokens which
    /// represent their share of the pool. The protocol team is minted their share of the swap fee
    /// accumulated in the pool before proceeding to add liquidity. It is recommended to use the
    /// Bubble v1 router (which performs additional safety checks) for this action.
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
            address initialLPTokenReceiver = address(1);
            _mint(initialLPTokenReceiver, MINIMUM_LIQUIDITY);
        } else {
            lpTokensToMint = ((amountAIn * totalLpTokenSupply) / reserveA).min(
                (amountBIn * totalLpTokenSupply) / reserveB
            );
        }
        if (lpTokensToMint == 0) revert BubbleV1Pool__ZeroLpTokensToMint();
        _mint(_receiver, lpTokensToMint);
        _updateReservesAndTWAP(balanceA, balanceB, reserveA, reserveB);
        if (getProtocolTeamMultisig() != address(0)) s_lastK = s_reserveA * s_reserveB;

        emit LiquidityAdded(msg.sender, _receiver, amountAIn, amountBIn, lpTokensToMint);

        return lpTokensToMint;
    }

    /// @notice Allows liquidity providers to exit their positions by withdrawing their liquidity
    /// based on their share of the pool. The protocol team is minted their share of the fee
    /// accumulated in the pool before proceeding to remove liquidity. It is recommended to use the
    /// Bubble v1 router (which performs additional safety checks) for this action.
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
            revert BubbleV1Pool__CannotWithdrawZeroTokenAmount();
        }
        _burn(address(this), lpTokensReceived);
        IERC20(s_tokenA).safeTransfer(_receiver, amountAOut);
        IERC20(s_tokenB).safeTransfer(_receiver, amountBOut);
        balanceA = IERC20(s_tokenA).balanceOf(address(this));
        balanceB = IERC20(s_tokenB).balanceOf(address(this));
        _updateReservesAndTWAP(balanceA, balanceB, reserveA, reserveB);
        if (getProtocolTeamMultisig() != address(0)) s_lastK = s_reserveA * s_reserveB;

        emit LiquidityRemoved(msg.sender, _receiver, amountAOut, amountBOut, lpTokensReceived);

        return (amountAOut, amountBOut);
    }

    /// @notice Allows swapping of tokens in either direction. Also allows flash swaps and
    /// flash loans, all packed in the same function. Additionally, users leveraging flash
    /// swaps and flash loans can invoke hooks before and after a swap.
    /// @param _swapParams The parameters for swapping.
    function swap(BubbleV1Types.SwapParams memory _swapParams) external globalLock {
        if (_swapParams.amountAOut == 0 && _swapParams.amountBOut == 0) {
            revert BubbleV1Pool__InsufficientOutputAmount();
        }
        (uint256 reserveA, uint256 reserveB) = getReserves();
        if (_swapParams.amountAOut >= reserveA || _swapParams.amountBOut >= reserveB) {
            revert BubbleV1Pool__OutputAmountGreaterThanReserves();
        }

        uint256 balanceA;
        uint256 balanceB;
        {
            if (_swapParams.receiver == s_tokenA || _swapParams.receiver == s_tokenB) {
                revert BubbleV1Pool__InvalidReceiver(_swapParams.receiver);
            }
            if (_swapParams.hookConfig.hookBeforeCall) {
                IBubbleV1Callee(_swapParams.receiver).hookBeforeCall(
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
                IBubbleV1Callee(_swapParams.receiver).onCall(
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
        if (amountAIn == 0 && amountBIn == 0) revert BubbleV1Pool__InsufficientInputAmount();
        {
            BubbleV1Types.Fraction memory poolFee = getPoolFee();
            uint256 balanceAAdjusted =
                (balanceA * poolFee.denominator) - (amountAIn * poolFee.numerator);
            uint256 balanceBAdjusted =
                (balanceB * poolFee.denominator) - (amountBIn * poolFee.numerator);
            if (
                balanceAAdjusted * balanceBAdjusted
                    < reserveA * reserveB * (poolFee.denominator ** 2)
            ) {
                revert BubbleV1Pool__InvalidK();
            }
        }
        _updateReservesAndTWAP(balanceA, balanceB, reserveA, reserveB);

        emit AmountSwapped(
            msg.sender,
            amountAIn,
            amountBIn,
            _swapParams.amountAOut,
            _swapParams.amountBOut,
            _swapParams.receiver
        );

        if (_swapParams.hookConfig.hookAfterCall) {
            IBubbleV1Callee(_swapParams.receiver).hookAfterCall(
                msg.sender, _swapParams.amountAOut, _swapParams.amountBOut, _swapParams.data
            );
        }
    }

    /// @notice Allows anyone to sync the balances held by the contract with the currently
    /// tracked token reserves by removing the excess amounts.
    /// @param _receiver The address to direct the excess amounts to.
    function syncBalancesBasedOnReserves(address _receiver) external globalLock {
        (address tokenA, address tokenB) = getPoolTokens();

        uint256 excessTokenAAmount = IERC20(tokenA).balanceOf(address(this)) - s_reserveA;
        uint256 excessTokenBAmount = IERC20(tokenB).balanceOf(address(this)) - s_reserveB;
        if (excessTokenAAmount > 0) IERC20(tokenA).safeTransfer(_receiver, excessTokenAAmount);
        if (excessTokenBAmount > 0) IERC20(tokenB).safeTransfer(_receiver, excessTokenBAmount);
    }

    /// @notice Allows anyone to sync the currently tracked token reserves with the actual token
    /// balances held by the contract by setting the reserve values to the actual token balances
    /// held by the pool.
    function syncReservesBasedOnBalances() external globalLock {
        _updateReservesAndTWAP(
            IERC20(s_tokenA).balanceOf(address(this)),
            IERC20(s_tokenB).balanceOf(address(this)),
            s_reserveA,
            s_reserveB
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
    function _updateReservesAndTWAP(
        uint256 _balanceA,
        uint256 _balanceB,
        uint256 _reserveA,
        uint256 _reserveB
    )
        internal
    {
        if (_balanceA > type(uint112).max || _balanceB > type(uint112).max) {
            revert BubbleV1Pool__BalancesOverflow();
        }
        unchecked {
            uint32 blockTimestamp = uint32(block.timestamp % BubbleV1Library.Q112);
            uint32 timeElapsed = blockTimestamp - s_blockTimestampLast;

            if (timeElapsed > 0 && _reserveA != 0 && _reserveB != 0) {
                s_priceACumulativeLast += uint256(
                    BubbleV1Library.uqdiv(
                        BubbleV1Library.encode(uint112(_reserveB)), uint112(_reserveA)
                    )
                ) * timeElapsed;
                s_priceBCumulativeLast += uint256(
                    BubbleV1Library.uqdiv(
                        BubbleV1Library.encode(uint112(_reserveA)), uint112(_reserveB)
                    )
                ) * timeElapsed;
            }

            s_blockTimestampLast = blockTimestamp;
        }

        s_reserveA = _balanceA;
        s_reserveB = _balanceB;

        emit ReservesUpdated(_balanceA, _balanceB);
    }

    /// @notice Mint's the protocol's cut of the swap fee to the protocol team's multi-sig address.
    /// Also updates the TWAP.
    /// @param _reserveA Token A's reserve.
    /// @param _reserveB Token B's reserve.
    function _mintProtocolFee(uint256 _reserveA, uint256 _reserveB) internal {
        address protocolTeamMultisig = getProtocolTeamMultisig();
        BubbleV1Types.Fraction memory protocolFee = getProtocolFee();
        uint256 lastK = s_lastK;
        uint256 totalLpTokenSupply = totalSupply;

        if (protocolTeamMultisig == address(0)) {
            if (s_lastK != 0) s_lastK = 0;
            return;
        }

        if (lastK != 0) {
            uint256 rootK = (_reserveA * _reserveB).sqrt();
            uint256 rootKLast = lastK.sqrt();
            if (rootK > rootKLast) {
                uint256 numerator =
                    (totalLpTokenSupply * (rootK - rootKLast) * protocolFee.numerator);
                uint256 denominator = (rootK * (protocolFee.denominator - protocolFee.numerator))
                    + (rootKLast * protocolFee.numerator);
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
        if (_token != s_tokenA && _token != s_tokenB) return false;
        return true;
    }

    /// @notice Gets the address of the BubbleV1Factory.
    /// @return The factory address.
    function getFactory() external view returns (address) {
        return i_factory;
    }

    /// @notice Gets the data associated with the TWAP oracle - the last update timestamp,
    /// the cumulative token A price and cumulative token B price.
    function getTWAPData() external view returns (uint32, uint256, uint256) {
        return (s_blockTimestampLast, s_priceACumulativeLast, s_priceBCumulativeLast);
    }

    /// @notice Gets the protocol team's multi-sig address from the factory. Used to direct
    /// part of the swap fee to the protocol team.
    /// @return The protocol team's multi-sig address.
    function getProtocolTeamMultisig() public view returns (address) {
        return IBubbleV1Factory(i_factory).getProtocolTeamMultisig();
    }

    /// @notice Gets the protocol's cut of the swap fee from the factory.
    /// @return The protocol fee, a struct with numerator and denominator fields.
    function getProtocolFee() public view returns (BubbleV1Types.Fraction memory) {
        return IBubbleV1Factory(i_factory).getProtocolFee();
    }

    /// @notice Gets the swap fee from the factory.
    /// @return The swap fee, a struct with numerator and denominator fields.
    function getPoolFee() public view returns (BubbleV1Types.Fraction memory) {
        return IBubbleV1Factory(i_factory).getTokenPairToFee(s_tokenA, s_tokenB);
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
