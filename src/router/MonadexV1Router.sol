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

import { IWNative } from "../interfaces/IWNative.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { IMonadexV1Factory } from "../interfaces/IMonadexV1Factory.sol";
import { IMonadexV1Pool } from "../interfaces/IMonadexV1Pool.sol";
import { IMonadexV1Raffle } from "../interfaces/IMonadexV1Raffle.sol";
import { IMonadexV1Router } from "../interfaces/IMonadexV1Router.sol";

import { MonadexV1Library } from "../library/MonadexV1Library.sol";
import { MonadexV1Types } from "../library/MonadexV1Types.sol";

/**
 * @title MonadexV1Router
 * @author Monadex Labs -- mgnfy-view
 * @notice The router contract acts as a convenient interface to interact with Monadex pools.
 * It performs essential safety checks, and is also the only way to purchase raffle tickets.
 */
contract MonadexV1Router is IMonadexV1Router {
    using SafeERC20 for IERC20;

    ///////////////////////
    /// State Variables ///
    ///////////////////////

    address private immutable i_factory;
    address private immutable i_raffle;
    address private immutable i_wNative;

    //////////////
    /// Errors ///
    //////////////

    error MonadexV1Router__DeadlinePasssed(uint256 deadline);
    error MonadexV1Router__TransferFailed();
    error MonadexV1Router__InsufficientAAmount(uint256 amountA, uint256 amountAMin);
    error MonadexV1Router__InsufficientBAmount(uint256 amountB, uint256 amountBMin);
    error MonadexV1Router__InsufficientOutputAmount(uint256 amountOut, uint256 amountOutMin);
    error MonadexV1Router__ExcessiveInputAmount(uint256 amountIn, uint256 amountInMax);

    /////////////////
    /// Modifiers ///
    /////////////////

    modifier beforeDeadline(uint256 _deadline) {
        if (_deadline < block.timestamp) revert MonadexV1Router__DeadlinePasssed(_deadline);
        _;
    }

    ///////////////////
    /// Constructor ///
    ///////////////////

    constructor(address _factory, address _raffle, address _wNative) {
        i_factory = _factory;
        i_raffle = _raffle;
        i_wNative = _wNative;
    }

    //////////////////////////
    /// External Functions ///
    //////////////////////////

    /**
     * @notice Allows supplying liquidity to Monadex pools with safety checks.
     * @param _addLiquidityParams We needed to wrap these parameters in a struct to avoid
     * stack too deep errors. The parameters include:
     *                        - tokenA: Address of token A
     *                        - tokenB: Address of token B
     *                        - amountADesired: Maximum amount of token A to add
     *                                          as liquidity
     *                        - amountBDesired: Maximum amount of token B to add
     *                                          as liquidity
     *                        - amountAMin: Minimum amount of token A to add
     *                                      as liquidity
     *                        - amountBMin: Minimum amount of token B to add
     *                                      as liquidity
     *                        - receiver: The address to direct the LP tokens to
     *                        - deadline: UNIX timestamp before which the liquidity
     *                                    should be added
     * @return Amount of token A added.
     * @return Amount of token B added.
     * @return Amount of LP tokens received.
     */
    function addLiquidity(MonadexV1Types.AddLiquidity memory _addLiquidityParams)
        external
        beforeDeadline(_addLiquidityParams.deadline)
        returns (uint256, uint256, uint256)
    {
        (uint256 amountA, uint256 amountB) = _addLiquidityHelper(
            _addLiquidityParams.tokenA,
            _addLiquidityParams.tokenB,
            _addLiquidityParams.amountADesired,
            _addLiquidityParams.amountBDesired,
            _addLiquidityParams.amountAMin,
            _addLiquidityParams.amountBMin
        );
        address pool = MonadexV1Library.getPool(
            i_factory, _addLiquidityParams.tokenA, _addLiquidityParams.tokenB
        );
        IERC20(_addLiquidityParams.tokenA).safeTransferFrom(msg.sender, pool, amountA);
        IERC20(_addLiquidityParams.tokenB).safeTransferFrom(msg.sender, pool, amountB);
        uint256 lpTokensMinted = IMonadexV1Pool(pool).addLiquidity(_addLiquidityParams.receiver);

        return (amountA, amountB, lpTokensMinted);
    }

    function addLiquidityNative(MonadexV1Types.AddLiquidityNative memory _addLiquidityNativeParams)
        external
        payable
        beforeDeadline(_addLiquidityNativeParams.deadline)
        returns (uint256, uint256, uint256)
    {
        (uint256 amountToken, uint256 amountNative) = _addLiquidityHelper(
            _addLiquidityNativeParams.token,
            i_wNative,
            _addLiquidityNativeParams.amountTokenDesired,
            msg.value,
            _addLiquidityNativeParams.amountTokenMin,
            _addLiquidityNativeParams.amountNativeTokenMin
        );
        address pool =
            MonadexV1Library.getPool(i_factory, _addLiquidityNativeParams.token, i_wNative);
        IERC20(_addLiquidityNativeParams.token).safeTransferFrom(msg.sender, pool, amountToken);
        IWNative(payable(i_wNative)).deposit{ value: amountNative }();
        IERC20(i_wNative).safeTransfer(pool, amountNative);
        uint256 lpTokensMinted =
            IMonadexV1Pool(pool).addLiquidity(_addLiquidityNativeParams.receiver);
        if (msg.value > amountNative) {
            (bool success,) = payable(msg.sender).call{ value: msg.value - amountNative }("");
            if (!success) revert MonadexV1Router__TransferFailed();
        }

        return (amountToken, amountNative, lpTokensMinted);
    }

    function removeLiquidityNative(
        address _token,
        uint256 _lpTokensToBurn,
        uint256 _amountTokenMin,
        uint256 _amountNativeMin,
        address _receiver,
        uint256 _deadline
    )
        external
        beforeDeadline(_deadline)
        returns (uint256, uint256)
    {
        (uint256 amountToken, uint256 amountNative) = removeLiquidity(
            _token,
            i_wNative,
            _lpTokensToBurn,
            _amountTokenMin,
            _amountNativeMin,
            address(this),
            _deadline
        );
        IERC20(_token).safeTransfer(_receiver, amountToken);
        IWNative(payable(i_wNative)).withdraw(amountNative);
        (bool success,) = payable(_receiver).call{ value: amountNative }("");
        if (!success) revert MonadexV1Router__TransferFailed();

        return (amountToken, amountNative);
    }

    /**
     * @notice Swaps an exact amount of input tokens for any amount of output tokens
     * such that the safety checks pass.
     * @param _amountIn The amount of input tokens to swap.
     * @param _amountOutMin The minimum amount of output tokens to receive.
     * @param _path An array of token addresses which forms the swap path in case a direct
     * path does not exist from token A to B.
     * @param _receiver The address to direct the output amount to.
     * @param _deadline The UNIX timestamp before which the swap should be conducted.
     * @param _purchaseTickets Users can participate in a weekly lottery by purchasing
     * tickets during swaps. The purchase parameters include:
     *                       - purchaseTickets: True, if the user wants to pruchase tickets,
     *                                          false otherwise.
     *                       - multiplier: The multiplier to apply to the ticket purchase. The
     *                                     higher the multiplier, the higher fees is taken, and
     *                                     more raffle tickets are obtained. The multipliers are:
     *                                     - multiplier 1: 0.5% of swap amount as ticket price
     *                                     - multiplier 2: 1% of swap amount as ticket price
     *                                     - multiplier 3: 2% of swap amount as ticket price
     * @return The amounts obtained at each checkpoint of the swap path.
     * @return The amount of tickets obtained.
     */
    function swapExactTokensForTokens(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path,
        address _receiver,
        uint256 _deadline,
        MonadexV1Types.PurchaseTickets memory _purchaseTickets
    )
        external
        beforeDeadline(_deadline)
        returns (uint256[] memory, uint256)
    {
        uint256[] memory amounts = MonadexV1Library.getAmountsOut(i_factory, _amountIn, _path);
        if (amounts[amounts.length - 1] < _amountOutMin) {
            revert MonadexV1Router__InsufficientOutputAmount(
                amounts[amounts.length - 1], _amountOutMin
            );
        }
        IERC20(_path[0]).safeTransferFrom(
            msg.sender, MonadexV1Library.getPool(i_factory, _path[0], _path[1]), amounts[0]
        );
        _swap(amounts, _path, _receiver);

        uint256 tickets = 0;
        if (_purchaseTickets.purchaseTickets) {
            tickets = IMonadexV1Raffle(i_raffle).purchaseTickets(
                _path[0], _amountIn, _purchaseTickets.multiplier, _receiver
            );
        }

        return (amounts, tickets);
    }

    /**
     * @notice Swaps any amount of input tokens for exact amount of output tokens
     * such that the safety checks pass.
     * @param _amountOut The amount of output tokens to receive.
     * @param _amountInMax The maximum amount of input tokens to swap for.
     * @param _path An array of token addresses which forms the swap path in case a direct
     * path does not exist from token A to B.
     * @param _receiver The address to direct the output amount to.
     * @param _deadline The UNIX timestamp before which the swap should be conducted.
     * @param _purchaseTickets Users can participate in a weekly lottery by purchasing
     * tickets during swaps. The purchase parameters include:
     *                       - purchaseTickets: True, if the user wants to pruchase tickets,
     *                                          false otherwise.
     *                       - multiplier: The multiplier to apply to the ticket purchase. The
     *                                     higher the multiplier, the higher fees is taken, and
     *                                     more raffle tickets are obtained. The multipliers are:
     *                                     - multiplier 1: 0.5% of swap amount as ticket price
     *                                     - multiplier 2: 1% of swap amount as ticket price
     *                                     - multiplier 3: 2% of swap amount as ticket price
     * @return The amounts obtained at each checkpoint of the swap path.
     * @return The amount of tickets obtained.
     */
    function swapTokensForExactTokens(
        uint256 _amountOut,
        uint256 _amountInMax,
        address[] calldata _path,
        address _receiver,
        uint256 _deadline,
        MonadexV1Types.PurchaseTickets memory _purchaseTickets
    )
        external
        beforeDeadline(_deadline)
        returns (uint256[] memory, uint256)
    {
        uint256[] memory amounts = MonadexV1Library.getAmountsIn(i_factory, _amountOut, _path);
        if (amounts[0] > _amountInMax) {
            revert MonadexV1Router__ExcessiveInputAmount(amounts[0], _amountInMax);
        }
        IERC20(_path[0]).safeTransferFrom(
            msg.sender, MonadexV1Library.getPool(i_factory, _path[0], _path[1]), amounts[0]
        );
        _swap(amounts, _path, _receiver);

        uint256 tickets = 0;
        if (_purchaseTickets.purchaseTickets) {
            tickets = IMonadexV1Raffle(i_raffle).purchaseTickets(
                _path[0], amounts[0], _purchaseTickets.multiplier, _receiver
            );
        }

        return (amounts, tickets);
    }

    ////////////////////////
    /// Public Functions ///
    ////////////////////////

    /**
     * @notice Allows removal of liquidity from Monadex pools with safety checks.
     * @param _tokenA Address of token A.
     * @param _tokenB Address of token B.
     * @param _lpTokensToBurn Amount of LP tokens to burn.
     * @param _amountAMin Minimum amount of token A to withdraw from pool.
     * @param _amountBMin Minimum amount of token B to withdraw from pool.
     * @param _receiver The address to direct the withdrawn tokens to.
     * @param _deadline The UNIX timestamp before which the liquidity should be removed.
     * @return Amount of token A withdrawn.
     * @return Amount of token B withdrawn.
     */
    function removeLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _lpTokensToBurn,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _receiver,
        uint256 _deadline
    )
        public
        beforeDeadline(_deadline)
        returns (uint256, uint256)
    {
        address pool = MonadexV1Library.getPool(i_factory, _tokenA, _tokenB);
        IERC20(pool).safeTransferFrom(msg.sender, pool, _lpTokensToBurn);
        (uint256 amountA, uint256 amountB) = IMonadexV1Pool(pool).removeLiquidity(_receiver);
        (address tokenA,) = MonadexV1Library.sortTokens(_tokenA, _tokenB);
        (amountA, amountB) = tokenA == _tokenA ? (amountA, amountB) : (amountB, amountA);
        if (amountA < _amountAMin) {
            revert MonadexV1Router__InsufficientAAmount(amountA, _amountAMin);
        }
        if (amountB < _amountBMin) {
            revert MonadexV1Router__InsufficientBAmount(amountB, _amountBMin);
        }

        return (amountA, amountB);
    }

    //////////////////////////
    /// Internal Functions ///
    //////////////////////////

    /**
     * @notice A helper function to calculate safe amount A and amount B to add as
     * liquidity. Also deploys the pool for the token combination if one doesn't exist yet.
     * @param _tokenA Address of token A.
     * @param _tokenB Address of token B.
     * @param _amountADesired Maximum amount of token A to add as liquidity.
     * @param _amountBDesired Maximum amount of token B to add as liquidity.
     * @param _amountAMin Minimum amount of token A to add as liquidity.
     * @param _amountBMin Minimum amount of token B to add as liquidity.
     * @return Amount of token A to add.
     * @return Amount of token B to add.
     */
    function _addLiquidityHelper(
        address _tokenA,
        address _tokenB,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin
    )
        internal
        returns (uint256, uint256)
    {
        if (MonadexV1Library.getPool(i_factory, _tokenA, _tokenB) == address(0)) {
            IMonadexV1Factory(i_factory).deployPool(_tokenA, _tokenB);
        }
        (uint256 reserveA, uint256 reserveB) =
            MonadexV1Library.getReserves(i_factory, _tokenA, _tokenB);

        if (reserveA == 0 && reserveB == 0) {
            return (_amountADesired, _amountBDesired);
        } else {
            uint256 amountBOptimal = MonadexV1Library.quote(_amountADesired, reserveA, reserveB);
            if (amountBOptimal <= _amountBDesired) {
                if (amountBOptimal < _amountBMin) {
                    revert MonadexV1Router__InsufficientBAmount(amountBOptimal, _amountBMin);
                }
                return (_amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = MonadexV1Library.quote(_amountBDesired, reserveB, reserveA);
                if (amountAOptimal <= _amountADesired) {
                    if (amountAOptimal < _amountAMin) {
                        revert MonadexV1Router__InsufficientAAmount(amountAOptimal, _amountADesired);
                    }
                    return (amountAOptimal, _amountBDesired);
                }
            }
        }
    }

    /**
     * @notice A swap helper function to swap out the input amount for output amount along
     * a specific swap path.
     * @param _amounts The amounts to receive at each checkpoint along the swap path.
     * @param _path An array of token addresses which forms the swap path in case a direct
     * path does not exist from token A to B.
     * @param _receiver The address to direct the output amount to.
     */
    function _swap(uint256[] memory _amounts, address[] memory _path, address _receiver) internal {
        for (uint256 count = 0; count < _path.length - 1; ++count) {
            (address inputToken, address outputToken) = (_path[count], _path[count + 1]);
            (address tokenA,) = MonadexV1Library.sortTokens(inputToken, outputToken);
            uint256 amountOut = _amounts[count + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                inputToken == tokenA ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = count < _path.length - 2
                ? MonadexV1Library.getPool(i_factory, outputToken, _path[count + 2])
                : _receiver;
            MonadexV1Types.SwapParams memory swapParams = MonadexV1Types.SwapParams({
                amountAOut: amount0Out,
                amountBOut: amount1Out,
                receiver: to,
                hookConfig: MonadexV1Types.HookConfig({ hookBeforeCall: false, hookAfterCall: false }),
                data: new bytes(0)
            });
            IMonadexV1Pool(MonadexV1Library.getPool(i_factory, inputToken, outputToken)).swap(
                swapParams
            );
        }
    }
}
