// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IMonadexV1Callee } from "./interfaces/IMonadexV1Calle.sol";
import { IMonadexV1Factory } from "./interfaces/IMonadexV1Factory.sol";
import { MonadexV1Types } from "./library/MonadexV1Types.sol";
import { MonadexV1Utils } from "./library/MonadexV1Utils.sol";
import { Ownable, Ownable2Step } from "lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";
import { ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from
    "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

contract MonadexV1Pool is ERC20, Ownable2Step {
    using SafeERC20 for IERC20;
    using Math for uint256;

    address private immutable i_factory;
    address private immutable i_tokenA;
    address private immutable i_tokenB;
    uint256 private s_reserveA;
    uint256 private s_reserveB;
    uint256 constant MINIMUM_LIQUIDITY = 1_000;
    uint256 private s_lastK;
    bool private s_isLocked;

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
        uint256 indexed lpTokensBurnt
    );
    event AmountSwapped(
        address caller,
        uint256 amountAIn,
        uint256 amountBIn,
        uint256 amountAOut,
        uint256 amountBOut,
        address _receiver
    );
    event ReservesUpdated(uint256 indexed reserveA, uint256 indexed reserveB);

    error MonadexV1Pool__Locked();
    error MonadexV1Pool__ZeroLpTokensToMint();
    error MonadexV1Pool__CannotWithdrawZeroTokenAmount();
    error MonadexV1Pool__InsufficientOutputAmount();
    error MonadexV1Pool__OutputAmountGreaterThanReserves();
    error MonadexV1Pool__InvalidReceiver(address receiver);
    error MonadexV1Pool__InsufficientInputAmount();
    error MonadexV1Pool__InvalidK();

    modifier globalLock() {
        if (s_isLocked) revert MonadexV1Pool__Locked();
        s_isLocked = true;
        _;
        s_isLocked = false;
    }

    constructor(
        address _tokenA,
        address _tokenB
    )
        ERC20(
            string.concat(
                "Monadex", IERC20Metadata(_tokenA).name(), IERC20Metadata(_tokenB).name(), "Pool"
            ),
            string.concat("MDX", IERC20Metadata(_tokenA).symbol(), IERC20Metadata(_tokenB).symbol())
        )
        Ownable(msg.sender)
    {
        i_factory = msg.sender;
        i_tokenA = _tokenA;
        i_tokenB = _tokenB;
        s_isLocked = false;
        s_lastK = 0;
    }

    function addLiquidity(address _receiver) external globalLock returns (uint256) {
        (uint256 reserveA, uint256 reserveB) = getReserves();
        uint256 balanceA = IERC20(i_tokenA).balanceOf(address(this));
        uint256 balanceB = IERC20(i_tokenB).balanceOf(address(this));
        uint256 amountAIn = balanceA - reserveA;
        uint256 amountBIn = balanceB - reserveB;
        uint256 lpTokensToMint;

        _mintProtocolFee(reserveA, reserveB);
        uint256 totalLpTokenSupply = totalSupply();
        if (totalLpTokenSupply == 0) {
            lpTokensToMint = (amountAIn * amountBIn).sqrt() - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
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

    function removeLiquidity(address _receiver) external globalLock returns (uint256, uint256) {
        (uint256 reserveA, uint256 reserveB) = getReserves();
        uint256 balanceA = IERC20(i_tokenA).balanceOf(address(this));
        uint256 balanceB = IERC20(i_tokenB).balanceOf(address(this));
        uint256 lpTokensReceived = balanceOf(address(this));

        _mintProtocolFee(reserveA, reserveB);
        uint256 totalLpTokenSupply = totalSupply();
        uint256 amountAOut = (lpTokensReceived * balanceA) / totalLpTokenSupply;
        uint256 amountBOut = (lpTokensReceived * balanceB) / totalLpTokenSupply;
        if (amountAOut == 0 || amountBOut == 0) {
            revert MonadexV1Pool__CannotWithdrawZeroTokenAmount();
        }
        _burn(address(this), lpTokensReceived);
        IERC20(i_tokenA).safeTransfer(_receiver, amountAOut);
        IERC20(i_tokenB).safeTransfer(_receiver, amountBOut);
        balanceA = IERC20(i_tokenA).balanceOf(address(this));
        balanceB = IERC20(i_tokenB).balanceOf(address(this));
        _updateReserves(balanceA, balanceB);
        s_lastK = s_reserveA * s_reserveB;

        emit LiquidityRemoved(msg.sender, _receiver, amountAOut, amountBOut, lpTokensReceived);
        return (amountAOut, amountBOut);
    }

    function swap(
        uint256 _amountAOut,
        uint256 _amountBOut,
        address _receiver,
        MonadexV1Types.HookConfig memory _hookConfig,
        bytes calldata _data
    )
        external
        globalLock
    {
        if (_amountAOut == 0 && _amountBOut == 0) {
            revert MonadexV1Pool__InsufficientOutputAmount();
        }
        (uint256 reserveA, uint256 reserveB) = getReserves();
        if (_amountAOut >= reserveA || _amountBOut >= reserveB) {
            revert MonadexV1Pool__OutputAmountGreaterThanReserves();
        }

        uint256 balanceA;
        uint256 balanceB;
        {
            if (_receiver == i_tokenA || _receiver == i_tokenB) {
                revert MonadexV1Pool__InvalidReceiver(_receiver);
            }
            if (_hookConfig.hookBeforeCall) {
                IMonadexV1Callee(_receiver).hookBeforeCall(
                    msg.sender, _amountAOut, _amountBOut, _data
                );
            }
            if (_amountAOut > 0) IERC20(i_tokenA).safeTransfer(_receiver, _amountAOut); // optimistically transfer tokens
            if (_amountBOut > 0) IERC20(i_tokenB).safeTransfer(_receiver, _amountBOut); // optimistically transfer tokens
            if (_data.length > 0) {
                IMonadexV1Callee(_receiver).onCall(msg.sender, _amountAOut, _amountBOut, _data);
            }
            balanceA = IERC20(i_tokenA).balanceOf(address(this));
            balanceB = IERC20(i_tokenB).balanceOf(address(this));
        }
        uint256 amountAIn =
            balanceA > reserveA - _amountAOut ? balanceA - (reserveA - _amountAOut) : 0;
        uint256 amountBIn =
            balanceB > reserveB - _amountBOut ? balanceB - (reserveB - _amountBOut) : 0;
        if (amountAIn == 0 && amountBIn == 0) revert MonadexV1Pool__InsufficientInputAmount();
        {
            MonadexV1Types.Fee memory poolFee = getPoolFee();
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

        emit AmountSwapped(msg.sender, amountAIn, amountBIn, _amountAOut, _amountBOut, _receiver);

        if (_hookConfig.hookAfterCall) {
            IMonadexV1Callee(_receiver).hookAfterCall(msg.sender, _amountAOut, _amountBOut, _data);
        }
    }

    function syncBalancesBasedOnReserves(address _receiver) external globalLock {
        (address tokenA, address tokenB) = getPoolTokens();
        IERC20(tokenA).safeTransfer(_receiver, IERC20(tokenA).balanceOf(address(this)) - s_reserveA);
        IERC20(tokenB).safeTransfer(_receiver, IERC20(tokenB).balanceOf(address(this)) - s_reserveB);
    }

    function syncReservesBasedOnBalances() external globalLock {
        _updateReserves(
            IERC20(i_tokenA).balanceOf(address(this)), IERC20(i_tokenB).balanceOf(address(this))
        );
    }

    function getProtocolTeamMultisig() public view returns (address) {
        return IMonadexV1Factory(i_factory).getProtocolTeamMultisig();
    }

    function getProtocolFee() public view returns (MonadexV1Types.Fee memory) {
        return IMonadexV1Factory(i_factory).getProtocolFee();
    }

    function getPoolFee() public view returns (MonadexV1Types.Fee memory) {
        return IMonadexV1Factory(i_factory).getTokenPairToFee(i_tokenA, i_tokenB);
    }

    function isPoolToken(address _token) public view returns (bool) {
        if (_token != i_tokenA && _token != i_tokenB) return false;
        return true;
    }

    function getPoolTokens() public view returns (address, address) {
        return (i_tokenA, i_tokenB);
    }

    function getReserves() public view returns (uint256, uint256) {
        return (s_reserveA, s_reserveB);
    }

    function _updateReserves(uint256 _reserveA, uint256 _reserveB) internal {
        s_reserveA = _reserveA;
        s_reserveB = _reserveB;

        emit ReservesUpdated(_reserveA, _reserveB);
    }

    function _mintProtocolFee(uint256 _reserveA, uint256 _reserveB) internal {
        address protocolTeamMultisig = IMonadexV1Factory(i_factory).getProtocolTeamMultisig();
        MonadexV1Types.Fee memory protocolFee = getProtocolFee();
        uint256 lastK = s_lastK;
        uint256 totalLpTokenSupply = totalSupply();

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
}
