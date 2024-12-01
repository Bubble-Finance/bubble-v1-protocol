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
import { IERC20Permit } from
    "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";

import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { IMonadexV1Factory } from "../interfaces/IMonadexV1Factory.sol";
import { IMonadexV1Pool } from "../interfaces/IMonadexV1Pool.sol";
import { IMonadexV1Raffle } from "../interfaces/IMonadexV1Raffle.sol";
import { IMonadexV1Router } from "../interfaces/IMonadexV1Router.sol";
import { IWNative } from "../interfaces/IWNative.sol";

import { MonadexV1Library } from "../library/MonadexV1Library.sol";
import { MonadexV1Types } from "../library/MonadexV1Types.sol";

/// @title MonadexV1Router.
/// @author Monadex Labs -- mgnfy-view.
/// @notice The router contract acts as a convenient interface to interact with Monadex pools.
/// It performs essential safety checks, and is also the only way to purchase raffle tickets.
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
    error MonadexV1Router__PermitFailed();
    error MonadexV1Router__InsufficientAAmount(uint256 amountA, uint256 amountAMin);
    error MonadexV1Router__InsufficientBAmount(uint256 amountB, uint256 amountBMin);
    error MonadexV1Router__InsufficientOutputAmount(uint256 amountOut, uint256 amountOutMin);
    error MonadexV1Router__ExcessiveInputAmount(uint256 amountIn, uint256 amountInMax);
    error MonadexV1Router__InvalidPath();
    error MonadexV1Router__TokenNotSupportedByRaffle();
    error MonadexV1Router__InsufficientTicketAmountReceived(
        uint256 ticketsReceived, uint256 minimumTicketsToReceive
    );

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

    /// @notice Initializes the factory, raffle and wNative addresses.
    /// @param _factory The MonadexV1Factory address.
    /// @param _raffle The MonadexV1Raffle address.
    /// @param _wNative The address of the wrapped native token.
    constructor(address _factory, address _raffle, address _wNative) {
        i_factory = _factory;
        i_raffle = _raffle;
        i_wNative = _wNative;
    }

    //////////////////////////
    /// External Functions ///
    //////////////////////////

    /// @notice Allows supplying liquidity to Monadex pools with safety checks.
    /// @param _addLiquidityParams The parameters required to add liquidity.
    /// @return Amount of token A added.
    /// @return Amount of token B added.
    /// @return Amount of LP tokens received.
    function addLiquidity(
        MonadexV1Types.AddLiquidity calldata _addLiquidityParams
    )
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

    /// @notice Allows supplying native currency as liquidity to Monadex pools with safety checks.
    /// @param _addLiquidityNativeParams The parameters required to add liquidity in native currency.
    /// @return Amount of token added.
    /// @return Amount of native currency added.
    /// @return Amount of LP tokens received.
    function addLiquidityNative(
        MonadexV1Types.AddLiquidityNative calldata _addLiquidityNativeParams
    )
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

    /// @notice Allows removal of liquidity from Monadex pools using a permit.
    /// @param _params The liquidity removal params.
    /// @return Amount of token A withdrawn.
    /// @return Amount of token B withdrawn.
    function removeLiquidityWithPermit(
        MonadexV1Types.RemoveLiquidityWithPermit calldata _params
    )
        external
        beforeDeadline(_params.deadline)
        returns (uint256, uint256)
    {
        address pool = MonadexV1Library.getPool(i_factory, _params.tokenA, _params.tokenB);
        uint256 value = _params.approveMax ? type(uint256).max : _params.lpTokensToBurn;

        try IERC20Permit(pool).permit(
            msg.sender, address(this), value, _params.deadline, _params.v, _params.r, _params.s
        ) { } catch {
            uint256 allowance = IERC20(pool).allowance(msg.sender, address(this));
            if (allowance < value) revert MonadexV1Router__PermitFailed();
        }

        return removeLiquidity(
            _params.tokenA,
            _params.tokenB,
            _params.lpTokensToBurn,
            _params.amountAMin,
            _params.amountBMin,
            _params.receiver,
            _params.deadline
        );
    }

    /// @notice Allows removal of native currency liquidity from Monadex pools using a permit.
    /// @param _params The liquidity removal params.
    /// @return Amount of tokens withdrawn.
    /// @return Amount of native currency withdrawn.
    function removeLiquidityNativeWithPermit(
        MonadexV1Types.RemoveLiquidityNativeWithPermit calldata _params
    )
        external
        beforeDeadline(_params.deadline)
        returns (uint256, uint256)
    {
        address pool = MonadexV1Library.getPool(i_factory, _params.token, i_wNative);
        uint256 value = _params.approveMax ? type(uint256).max : _params.lpTokensToBurn;

        try IERC20Permit(pool).permit(
            msg.sender, address(this), value, _params.deadline, _params.v, _params.r, _params.s
        ) { } catch {
            uint256 allowance = IERC20(pool).allowance(msg.sender, address(this));
            if (allowance < value) revert MonadexV1Router__PermitFailed();
        }

        return removeLiquidityNative(
            _params.token,
            _params.lpTokensToBurn,
            _params.amountTokenMin,
            _params.amountNativeMin,
            _params.receiver,
            _params.deadline
        );
    }

    /// @notice Swaps an exact amount of input tokens for any amount of output tokens
    /// such that the safety checks pass.
    /// @param _amountIn The amount of input tokens to swap.
    /// @param _amountOutMin The minimum amount of output tokens to receive.
    /// @param _path An array of token addresses which forms the swap path in case a direct
    /// path does not exist from token A to B.
    /// @param _receiver The address to direct the output amount to.
    /// @param _deadline The UNIX timestamp before which the swap should be conducted.
    /// @param _purchaseTickets Details about ticket purchase during swap.
    /// @return The amounts obtained at each checkpoint of the swap path.
    /// @return The amount of tickets obtained.
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
            tickets = _purchaseRaffleTickets(
                _purchaseTickets.multiplier,
                _path,
                amounts,
                _purchaseTickets.minimumTicketsToReceive,
                _receiver
            );
        }

        return (amounts, tickets);
    }

    /// @notice Swaps any amount of input tokens for exact amount of output tokens
    /// such that the safety checks pass.
    /// @param _amountOut The amount of output tokens to receive.
    /// @param _amountInMax The maximum amount of input tokens to swap for.
    /// @param _path An array of token addresses which forms the swap path in case a direct
    /// path does not exist from token A to B.
    /// @param _receiver The address to direct the output amount to.
    /// @param _deadline The UNIX timestamp before which the swap should be conducted.
    /// @param _purchaseTickets The parameters for ticket purchase during swap.
    /// @return The amounts obtained at each checkpoint of the swap path.
    /// @return The amount of tickets obtained.
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
            tickets = _purchaseRaffleTickets(
                _purchaseTickets.multiplier,
                _path,
                amounts,
                _purchaseTickets.minimumTicketsToReceive,
                _receiver
            );
        }

        return (amounts, tickets);
    }

    /// @notice Swaps an exact amount of ntive currency for any amount of output tokens
    /// such that the safety checks pass.
    /// @param _amountOutMin The minimum amount of output tokens to receive.
    /// @param _path An array of token addresses which forms the swap path in case a direct
    /// path does not exist from token A to B.
    /// @param _receiver The address to direct the output amount to.
    /// @param _deadline The UNIX timestamp before which the swap should be conducted.
    /// @param _purchaseTickets The parameters for ticket purchase during swap.
    /// @return The amounts obtained at each checkpoint of the swap path.
    /// @return The amount of tickets obtained.
    function swapExactNativeForTokens(
        uint256 _amountOutMin,
        address[] calldata _path,
        address _receiver,
        uint256 _deadline,
        MonadexV1Types.PurchaseTickets memory _purchaseTickets
    )
        external
        payable
        beforeDeadline(_deadline)
        returns (uint256[] memory, uint256)
    {
        if (_path[0] != i_wNative) revert MonadexV1Router__InvalidPath();
        uint256[] memory amounts = MonadexV1Library.getAmountsOut(i_factory, msg.value, _path);
        if (amounts[amounts.length - 1] < _amountOutMin) {
            revert MonadexV1Router__InsufficientOutputAmount(
                amounts[amounts.length - 1], _amountOutMin
            );
        }
        IWNative(payable(i_wNative)).deposit{ value: amounts[0] }();
        IERC20(i_wNative).safeTransfer(
            MonadexV1Library.getPool(i_factory, _path[0], _path[1]), amounts[0]
        );
        _swap(amounts, _path, _receiver);

        uint256 tickets = 0;
        if (_purchaseTickets.purchaseTickets) {
            tickets = _purchaseRaffleTickets(
                _purchaseTickets.multiplier,
                _path,
                amounts,
                _purchaseTickets.minimumTicketsToReceive,
                _receiver
            );
        }

        return (amounts, tickets);
    }

    /// @notice Swaps any amount of input tokens for exact amount of native currency
    /// such that the safety checks pass.
    /// @param _amountOut The amount of native currency to receive.
    /// @param _amountInMax The maximum amount of input tokens to swap for.
    /// @param _path An array of token addresses which forms the swap path in case a direct
    /// path does not exist from token A to B.
    /// @param _receiver The address to direct the output amount to.
    /// @param _deadline The UNIX timestamp before which the swap should be conducted.
    /// @param _purchaseTickets The parameters for ticket purchase during swap.
    /// @return The amounts obtained at each checkpoint of the swap path.
    /// @return The amount of tickets obtained.
    function swapTokensForExactNative(
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
        if (_path[_path.length - 1] != i_wNative) revert MonadexV1Router__InvalidPath();
        uint256[] memory amounts = MonadexV1Library.getAmountsIn(i_factory, _amountOut, _path);
        if (amounts[0] > _amountInMax) {
            revert MonadexV1Router__ExcessiveInputAmount(amounts[0], _amountInMax);
        }
        IERC20(_path[0]).safeTransferFrom(
            msg.sender, MonadexV1Library.getPool(i_factory, _path[0], _path[1]), amounts[0]
        );
        _swap(amounts, _path, address(this));
        IWNative(payable(i_wNative)).withdraw(amounts[amounts.length - 1]);
        (bool success,) = payable(_receiver).call{ value: amounts[amounts.length - 1] }("");
        if (!success) revert MonadexV1Router__TransferFailed();

        uint256 tickets = 0;
        if (_purchaseTickets.purchaseTickets) {
            tickets = _purchaseRaffleTickets(
                _purchaseTickets.multiplier,
                _path,
                amounts,
                _purchaseTickets.minimumTicketsToReceive,
                _receiver
            );
        }

        return (amounts, tickets);
    }

    /// @notice Swaps an exact amount of input tokens for any amount of native currency
    /// such that the safety checks pass.
    /// @param _amountIn The amount of input tokens to swap.
    /// @param _amountOutMin The minimum amount of native currency to receive.
    /// @param _path An array of token addresses which forms the swap path in case a direct
    /// path does not exist from token A to B.
    /// @param _receiver The address to direct the output amount to.
    /// @param _deadline The UNIX timestamp before which the swap should be conducted.
    /// @param _purchaseTickets The parameters for ticket purchase during swap.
    /// @return The amounts obtained at each checkpoint of the swap path.
    /// @return The amount of tickets obtained.
    function swapExactTokensForNative(
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
        if (_path[_path.length - 1] != i_wNative) revert MonadexV1Router__InvalidPath();
        uint256[] memory amounts = MonadexV1Library.getAmountsOut(i_factory, _amountIn, _path);
        if (amounts[amounts.length - 1] < _amountOutMin) {
            revert MonadexV1Router__InsufficientOutputAmount(
                amounts[amounts.length - 1], _amountOutMin
            );
        }
        IERC20(_path[0]).safeTransferFrom(
            msg.sender, MonadexV1Library.getPool(i_factory, _path[0], _path[1]), amounts[0]
        );
        _swap(amounts, _path, address(this));
        IWNative(payable(i_wNative)).withdraw(amounts[amounts.length - 1]);
        (bool success,) = payable(_receiver).call{ value: amounts[amounts.length - 1] }("");
        if (!success) revert MonadexV1Router__TransferFailed();

        uint256 tickets = 0;
        if (_purchaseTickets.purchaseTickets) {
            tickets = _purchaseRaffleTickets(
                _purchaseTickets.multiplier,
                _path,
                amounts,
                _purchaseTickets.minimumTicketsToReceive,
                _receiver
            );
        }

        return (amounts, tickets);
    }

    /// @notice Swaps any amount of native currency for exact amount of output tokens
    /// such that the safety checks pass.
    /// @param _amountOut The amount of output tokens to receive.
    /// @param _path An array of token addresses which forms the swap path in case a direct
    /// path does not exist from token A to B.
    /// @param _receiver The address to direct the output amount to.
    /// @param _deadline The UNIX timestamp before which the swap should be conducted.
    /// @param _purchaseTickets The parameters for ticket purchase during swap.
    /// @return The amounts obtained at each checkpoint of the swap path.
    /// @return The amount of tickets obtained.
    function swapNativeForExactTokens(
        uint256 _amountOut,
        address[] calldata _path,
        address _receiver,
        uint256 _deadline,
        MonadexV1Types.PurchaseTickets memory _purchaseTickets
    )
        external
        payable
        beforeDeadline(_deadline)
        returns (uint256[] memory, uint256)
    {
        if (_path[0] != i_wNative) revert MonadexV1Router__InvalidPath();
        uint256[] memory amounts = MonadexV1Library.getAmountsIn(i_factory, _amountOut, _path);
        if (amounts[0] > msg.value) {
            revert MonadexV1Router__ExcessiveInputAmount(amounts[0], msg.value);
        }
        IWNative(payable(i_wNative)).deposit{ value: amounts[0] }();
        IERC20(i_wNative).safeTransfer(
            MonadexV1Library.getPool(i_factory, _path[0], _path[1]), amounts[0]
        );
        _swap(amounts, _path, _receiver);
        if (msg.value > amounts[0]) {
            (bool success,) = payable(msg.sender).call{ value: msg.value - amounts[0] }("");
            if (!success) revert MonadexV1Router__TransferFailed();
        }

        uint256 tickets = 0;
        if (_purchaseTickets.purchaseTickets) {
            tickets = _purchaseRaffleTickets(
                _purchaseTickets.multiplier,
                _path,
                amounts,
                _purchaseTickets.minimumTicketsToReceive,
                _receiver
            );
        }

        return (amounts, tickets);
    }

    ////////////////////////
    /// Public Functions ///
    ////////////////////////

    /// @notice Allows removal of liquidity from Monadex pools with safety checks.
    /// @param _tokenA Address of token A.
    /// @param _tokenB Address of token B.
    /// @param _lpTokensToBurn Amount of LP tokens to burn.
    /// @param _amountAMin Minimum amount of token A to withdraw from pool.
    /// @param _amountBMin Minimum amount of token B to withdraw from pool.
    /// @param _receiver The address to direct the withdrawn tokens to.
    /// @param _deadline The UNIX timestamp before which the liquidity should be removed.
    /// @return Amount of token A withdrawn.
    /// @return Amount of token B withdrawn.
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

    /// @notice Allows removal of native currency liquidity from Monadex pools with safety checks.
    /// @param _token Address of token.
    /// @param _lpTokensToBurn Amount of LP tokens to burn.
    /// @param _amountTokenMin Minimum amount of token to withdraw from pool.
    /// @param _amountNativeMin Minimum amount of native currency to withdraw from pool.
    /// @param _receiver The address to direct the withdrawn tokens to.
    /// @param _deadline The UNIX timestamp before which the liquidity should be removed.
    /// @return Amount of token withdrawn.
    /// @return Amount of native currency withdrawn.
    function removeLiquidityNative(
        address _token,
        uint256 _lpTokensToBurn,
        uint256 _amountTokenMin,
        uint256 _amountNativeMin,
        address _receiver,
        uint256 _deadline
    )
        public
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

    //////////////////////////
    /// Internal Functions ///
    //////////////////////////

    /// @notice A helper function to calculate safe amount A and amount B to add as
    /// liquidity. Also deploys the pool for the token pair if one doesn't exist yet.
    /// @param _tokenA Address of token A.
    /// @param _tokenB Address of token B.
    /// @param _amountADesired Maximum amount of token A to add as liquidity.
    /// @param _amountBDesired Maximum amount of token B to add as liquidity.
    /// @param _amountAMin Minimum amount of token A to add as liquidity.
    /// @param _amountBMin Minimum amount of token B to add as liquidity.
    /// @return Amount of token A to add.
    /// @return Amount of token B to add.
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

    /// @notice A swap helper function to swap out the input amount for output amount along
    /// a specific swap path.
    /// @param _amounts The amounts to receive at each checkpoint along the swap path.
    /// @param _path An array of token addresses which forms the swap path in case a direct
    /// path does not exist from token A to B.
    /// @param _receiver The address to direct the output amount to.
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

    /// @notice Allows users to purchase raffle tickets during a swap.
    /// @param _multiplier The multiplier to apply on the swap amount.
    /// @param _path The swap path.
    /// @param _amounts The amount of tokens at each checkpoint of the swap path.
    /// @param _minimumTicketsToReceive The minimum number of tickets to receive.
    /// @param _receiver The address of the receiver of tickets.
    function _purchaseRaffleTickets(
        MonadexV1Types.Multipliers _multiplier,
        address[] memory _path,
        uint256[] memory _amounts,
        uint256 _minimumTicketsToReceive,
        address _receiver
    )
        internal
        returns (uint256)
    {
        uint256 ticketsReceived;
        if (IMonadexV1Raffle(i_raffle).isSupportedToken(_path[0])) {
            ticketsReceived = IMonadexV1Raffle(i_raffle).purchaseTickets(
                msg.sender, _path[0], _amounts[0], _multiplier, _receiver
            );
        } else if (IMonadexV1Raffle(i_raffle).isSupportedToken(_path[_path.length - 1])) {
            ticketsReceived = IMonadexV1Raffle(i_raffle).purchaseTickets(
                msg.sender,
                _path[_path.length - 1],
                _amounts[_amounts.length - 1],
                _multiplier,
                _receiver
            );
        } else {
            revert MonadexV1Router__TokenNotSupportedByRaffle();
        }

        if (ticketsReceived < _minimumTicketsToReceive) {
            revert MonadexV1Router__InsufficientTicketAmountReceived(
                ticketsReceived, _minimumTicketsToReceive
            );
        }

        return ticketsReceived;
    }

    ///////////////////////////////
    /// View and Pure Functions ///
    ///////////////////////////////

    /// @notice Gets the factory's address.
    /// @return The factory's address.
    function getFactory() external view returns (address) {
        return i_factory;
    }

    /// @notice Gets the raffle contract's address.
    /// @return The raffle contract's address.
    function getRaffle() external view returns (address) {
        return i_raffle;
    }

    /// @notice Gets the native token's address.
    /// @return The native token's address.
    function getWNative() external view returns (address) {
        return i_wNative;
    }

    function quote(
        uint256 _amountA,
        uint256 _reserveA,
        uint256 _reserveB
    )
        external
        pure
        returns (uint256)
    {
        return MonadexV1Library.quote(_amountA, _reserveA, _reserveB);
    }

    function getAmountOut(
        uint256 _amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut,
        MonadexV1Types.Fraction memory _poolFee
    )
        external
        pure
        returns (uint256)
    {
        return MonadexV1Library.getAmountOut(_amountIn, _reserveIn, _reserveOut, _poolFee);
    }

    function getAmountIn(
        uint256 _amountOut,
        uint256 _reserveIn,
        uint256 _reserveOut,
        MonadexV1Types.Fraction memory _poolFee
    )
        external
        pure
        returns (uint256)
    {
        return MonadexV1Library.getAmountOut(_amountOut, _reserveIn, _reserveOut, _poolFee);
    }

    function getAmountsOut(
        uint256 _amountIn,
        address[] calldata _path
    )
        external
        view
        returns (uint256[] memory)
    {
        return MonadexV1Library.getAmountsOut(i_factory, _amountIn, _path);
    }

    function getAmountsIn(
        uint256 _amountOut,
        address[] calldata _path
    )
        public
        view
        returns (uint256[] memory)
    {
        return MonadexV1Library.getAmountsIn(i_factory, _amountOut, _path);
    }
}
