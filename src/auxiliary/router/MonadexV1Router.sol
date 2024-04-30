// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IMonadexV1Factory } from "../../core/interfaces/IMonadexV1Factory.sol";
import { IMonadexV1Pool } from "../../core/interfaces/IMonadexV1Pool.sol";
import { MonadexV1Types } from "../../core/library/MonadexV1Types.sol";
import { MonadexV1Utils } from "../../core/library/MonadexV1Utils.sol";
import { IMonadexV1Raffle } from "../interfaces/IMonadexV1Raffle.sol";
import { MonadexV1AuxiliaryLibrary } from "../library/MonadexV1AuxiliaryLibrary.sol";
import { MonadexV1AuxiliaryTypes } from "../library/MonadexV1AuxiliaryTypes.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract MonadexV1Router {
    using SafeERC20 for IERC20;

    address private immutable i_factory;
    address private immutable i_raffle;

    error MonadexV1Router__DeadlinePasssed(uint256 deadline);
    error MonadexV1Router__InsufficientBAmount(uint256 amountB, uint256 amountBMin);
    error MonadexV1Router__InsufficientAAmount(uint256 amountA, uint256 amountAMin);
    error MonadexV1Router__InsufficientOutputAmount(uint256 amountOut, uint256 amountOutMin);
    error MonadexV1Router__ExcessiveInputAmount(uint256 amountIn, uint256 amountInMax);

    modifier beforeDeadline(uint256 _deadline) {
        if (_deadline <= block.timestamp) revert MonadexV1Router__DeadlinePasssed(_deadline);
        _;
    }

    constructor(address _factory, address _raffle) {
        i_factory = _factory;
        i_raffle = _raffle;
    }

    function addLiquidity(MonadexV1AuxiliaryTypes.AddLiquidity memory _addLiquidityParams)
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
        address pool = MonadexV1AuxiliaryLibrary.getPool(
            i_factory, _addLiquidityParams.tokenA, _addLiquidityParams.tokenB
        );
        IERC20(_addLiquidityParams.tokenA).safeTransfer(pool, amountA);
        IERC20(_addLiquidityParams.tokenB).safeTransfer(pool, amountB);
        uint256 lpTokensMinted = IMonadexV1Pool(pool).addLiquidity(_addLiquidityParams.receiver);

        return (amountA, amountB, lpTokensMinted);
    }

    function removeLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _lpTokensToBurn,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _receiver,
        uint256 _deadline
    )
        external
        beforeDeadline(_deadline)
        returns (uint256, uint256)
    {
        address pool = MonadexV1AuxiliaryLibrary.getPool(i_factory, _tokenA, _tokenB);
        IERC20(pool).safeTransferFrom(msg.sender, pool, _lpTokensToBurn); // send lp tokens to pool
        (uint256 amountA, uint256 amountB) = IMonadexV1Pool(pool).removeLiquidity(_receiver);
        (address tokenA,) = MonadexV1Utils.sortTokens(_tokenA, _tokenB);
        (amountA, amountB) = tokenA == _tokenA ? (amountA, amountB) : (amountB, amountA);
        if (amountA < _amountAMin) {
            revert MonadexV1Router__InsufficientAAmount(amountA, _amountAMin);
        }
        if (amountB < _amountBMin) {
            revert MonadexV1Router__InsufficientBAmount(amountB, _amountBMin);
        }

        return (amountA, amountB);
    }

    function swapExactTokensForTokens(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path,
        address _receiver,
        uint256 _deadline
    )
        external
        beforeDeadline(_deadline)
        returns (uint256[] memory)
    {
        uint256[] memory amounts =
            MonadexV1AuxiliaryLibrary.getAmountsOut(i_factory, _amountIn, _path);
        if (amounts[amounts.length - 1] < _amountOutMin) {
            revert MonadexV1Router__InsufficientOutputAmount(
                amounts[amounts.length - 1], _amountOutMin
            );
        }
        IERC20(_path[0]).safeTransferFrom(
            msg.sender, MonadexV1AuxiliaryLibrary.getPool(i_factory, _path[0], _path[1]), amounts[0]
        );
        _swap(amounts, _path, _receiver);

        return amounts;
    }

    function swapTokensForExactTokens(
        uint256 _amountOut,
        uint256 _amountInMax,
        address[] calldata _path,
        address _receiver,
        uint256 _deadline
    )
        external
        beforeDeadline(_deadline)
        returns (uint256[] memory)
    {
        uint256[] memory amounts =
            MonadexV1AuxiliaryLibrary.getAmountsIn(i_factory, _amountOut, _path);
        if (amounts[0] > _amountInMax) {
            revert MonadexV1Router__ExcessiveInputAmount(amounts[0], _amountInMax);
        }
        IERC20(_path[0]).safeTransferFrom(
            msg.sender, MonadexV1AuxiliaryLibrary.getPool(i_factory, _path[0], _path[1]), amounts[0]
        );
        _swap(amounts, _path, _receiver);

        return amounts;
    }

    function _addLiquidityHelper(
        address _tokenA,
        address _tokenB,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin
    )
        private
        returns (uint256, uint256)
    {
        if (MonadexV1AuxiliaryLibrary.getPool(i_factory, _tokenA, _tokenB) == address(0)) {
            IMonadexV1Factory(i_factory).deployPool(_tokenA, _tokenB);
        }
        (uint256 reserveA, uint256 reserveB) =
            MonadexV1AuxiliaryLibrary.getReserves(i_factory, _tokenA, _tokenB);

        if (reserveA == 0 && reserveB == 0) {
            return (_amountADesired, _amountADesired);
        } else {
            uint256 amountBOptimal =
                MonadexV1AuxiliaryLibrary.quote(_amountADesired, reserveA, reserveB);
            if (amountBOptimal <= _amountBDesired) {
                if (amountBOptimal < _amountBMin) {
                    revert MonadexV1Router__InsufficientBAmount(amountBOptimal, _amountBMin);
                }
                return (_amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal =
                    MonadexV1AuxiliaryLibrary.quote(_amountBDesired, reserveB, reserveA);
                if (amountAOptimal <= _amountADesired) {
                    if (amountAOptimal < _amountAMin) {
                        revert MonadexV1Router__InsufficientAAmount(amountAOptimal, _amountADesired);
                    }
                    return (amountAOptimal, _amountBDesired);
                }
            }
        }
    }

    function _swap(uint256[] memory _amounts, address[] memory _path, address _receiver) private {
        for (uint256 count = 0; count < _path.length - 1; ++count) {
            (address inputToken, address outputToken) = (_path[count], _path[count + 1]);
            (address tokenA,) = MonadexV1Utils.sortTokens(inputToken, outputToken);
            uint256 amountOut = _amounts[count + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                inputToken == tokenA ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = count < _path.length - 2
                ? MonadexV1AuxiliaryLibrary.getPool(i_factory, outputToken, _path[count + 2])
                : _receiver;
            MonadexV1Types.SwapParams memory swapParams = MonadexV1Types.SwapParams({
                amountAOut: amount0Out,
                amountBOut: amount1Out,
                receiver: to,
                hookConfig: MonadexV1Types.HookConfig({ hookBeforeCall: false, hookAfterCall: false }),
                data: new bytes(0)
            });
            IMonadexV1Pool(MonadexV1AuxiliaryLibrary.getPool(i_factory, inputToken, outputToken))
                .swap(swapParams);
        }
    }
}
