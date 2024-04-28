// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IMonadexV1Factory } from "../../core/interfaces/IMonadexV1Factory.sol";
import { IMonadexV1Pool } from "../../core/interfaces/IMonadexV1Pool.sol";
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
    error MonadexV1Router__InsufficientBAmount(uint256 amountBOptimal, uint256 amountBMin);
    error MonadexV1Router__InsufficientAAmount(uint256 amountAOptimal, uint256 amountAMin);

    modifier beforeDeadline(uint256 _deadline) {
        if (_deadline < block.timestamp) revert MonadexV1Router__DeadlinePasssed(_deadline);
        _;
    }

    constructor(address _factory, address _raffle) {
        i_factory = _factory;
        i_raffle = _raffle;
    }

    function addLiquidity(MonadexV1AuxiliaryTypes.AddLiquidity memory _addLiquidityParams)
        external
        beforeDeadline(_addLiquidityParams.deadline)
        returns (uint256, uint256, uint256, uint256)
    {
        (uint256 amountA, uint256 amountB) = _addLiquidityHelper(
            _addLiquidityParams.tokenA,
            _addLiquidityParams.tokenB,
            _addLiquidityParams.amountADesired,
            _addLiquidityParams.amountBDesired,
            _addLiquidityParams.amountAMin,
            _addLiquidityParams.amountBMin
        );
        address pool = IMonadexV1Factory(i_factory).getTokenPairToPool(
            _addLiquidityParams.tokenA, _addLiquidityParams.tokenB
        );
        IERC20(_addLiquidityParams.tokenA).safeTransfer(pool, amountA);
        IERC20(_addLiquidityParams.tokenB).safeTransfer(pool, amountB);
        uint256 lpTokensMinted = IMonadexV1Pool(pool).addLiquidity(_addLiquidityParams.receiver);

        uint256 ticketsPurchased;
        // if (_addLiquidityParams.purchaseTickets.purchaseTickets) {
        //     ticketsPurchased = _purchaseTicketsFromRaffleContract(
        //         _addLiquidityParams.tokenA,
        //         _addLiquidityParams.tokenB,
        //         amountA,
        //         amountB,
        //         _addLiquidityParams.receiver,
        //         _addLiquidityParams.purchaseTickets
        //     );
        // }

        return (amountA, amountB, lpTokensMinted, ticketsPurchased);
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
        if (IMonadexV1Factory(i_factory).getTokenPairToPool(_tokenA, _tokenB) == address(0)) {
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

    // function _purchaseTicketsFromRaffleContract(
    //     address _tokenA,
    //     address _tokenB,
    //     uint256 _amountA,
    //     uint256 _amountB,
    //     address _receiver,
    //     MonadexV1AuxiliaryTypes.PurchaseTickets memory _purchaseTickets
    // )
    //     internal
    //     returns (uint256)
    // {
    //     (uint256 amountAToSend, uint256 amountBToSend) = MonadexV1AuxiliaryLibrary
    //         .getTicketAmountBasedOnMultiplier(_amountA, _amountB, _purchaseTickets.multiplier);
    //     IERC20(_tokenA).safeTransfer(i_raffle, amountAToSend);
    //     IERC20(_tokenA).safeTransfer(i_raffle, amountBToSend);

    //     return IMonadexV1Raffle(i_raffle).purchaseTickets(
    //         _tokenA, _tokenB, amountAToSend, amountBToSend, _receiver
    //     );
    // }
}
