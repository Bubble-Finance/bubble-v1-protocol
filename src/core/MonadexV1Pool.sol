// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

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

    address private s_tokenA;
    address private s_tokenB;
    uint256 private s_reserveA;
    uint256 private s_reserveB;
    address private s_protocolTeamMultisig;
    MonadexV1Types.Fee private s_protocolFee;
    MonadexV1Types.Fee private s_poolFee;
    uint256 constant MINIMUM_LIQUIDITY = 1_000;

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
    event ReservesUpdated(uint256 reserveA, uint256 reserveB);
    event ProtocolTeamMultisigSet(address protocolTeamMultisig);
    event ProtocolFeeSet(MonadexV1Types.Fee protocolFee);

    error MonadexV1Pool__EntryNotAllowedWhenFlashSwappingOrLoaning();
    error MonadexV1Pool__DeadlinePassed(uint256 deadline);
    error MonadexV1Pool__NotAPoolToken(address token);
    error MonadexV1Pool__InsufficientReserves(address token, uint256 reserve);
    error MonadexV1Pool__FlashLoanNotPaid(uint256 amountPaid, uint256 paybackAmount);
    error MonadexV1Pool__InvalidReceiver(address receiver);
    error MonadexV1Pool__ZeroLpTokensToMint();
    error MonadexV1Pool__CannotWithdrawZeroTokenAmount();
    error MonadexV1Pool__Locked();

    modifier globalLock() {
        if (s_isLocked) revert MonadexV1Pool__Locked();
        s_isLocked = true;
        _;
        s_isLocked = false;
    }

    modifier beforeDeadline(uint256 _deadline) {
        if (_deadline <= block.timestamp) revert MonadexV1Pool__DeadlinePassed(_deadline);
        _;
    }

    constructor(
        address _tokenA,
        address _tokenB,
        MonadexV1Types.Fee memory _protocolFee,
        MonadexV1Types.Fee memory _poolFee,
        address _protocolTeamMultisig
    )
        ERC20(
            string.concat("Monadex", IERC20Metadata(_tokenA).name(), IERC20Metadata(_tokenB).name()),
            string.concat("MDX", IERC20Metadata(_tokenA).symbol(), IERC20Metadata(_tokenB).symbol())
        )
        Ownable(msg.sender)
    {
        s_tokenA = _tokenA;
        s_tokenB = _tokenB;
        s_protocolFee = _protocolFee;
        s_poolFee = _poolFee;
        s_isLocked = false;
        s_protocolTeamMultisig = _protocolTeamMultisig;
    }

    function addLiquidity(address _receiver) external globalLock returns (uint256) {
        (uint256 reserveA, uint256 reserveB) = getReserves();
        (address tokenA, address tokenB) = getPoolTokens();
        uint256 balanceA = IERC20(tokenA).balanceOf(address(this));
        uint256 balanceB = IERC20(tokenB).balanceOf(address(this));
        uint256 amountAIn = balanceA - reserveA;
        uint256 amountBIn = balanceB - reserveB;
        uint256 totalLpTokenSupply = totalSupply();
        uint256 lpTokensToMint;
        MonadexV1Types.Fee memory protocolFee = s_protocolFee;

        uint256 protocolFeeOnAmountAIn = MonadexV1Utils.getProtocolFeeForAmount(
            amountAIn, protocolFee.feeNumerator, protocolFee.feeDenominator
        );
        uint256 protocolFeeOnAmountBIn = MonadexV1Utils.getProtocolFeeForAmount(
            amountBIn, protocolFee.feeNumerator, protocolFee.feeDenominator
        );
        _sendFeeToProtocolTeamMultisig(tokenA, protocolFeeOnAmountAIn);
        _sendFeeToProtocolTeamMultisig(tokenB, protocolFeeOnAmountBIn);
        amountAIn -= protocolFeeOnAmountAIn;
        amountBIn -= protocolFeeOnAmountBIn;

        if (totalLpTokenSupply == 0) {
            lpTokensToMint = (amountAIn * amountBIn).sqrt();
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            lpTokensToMint = ((amountAIn * totalLpTokenSupply) / reserveA).min(
                (amountBIn * totalLpTokenSupply) / reserveB
            );
        }
        if (lpTokensToMint == 0) revert MonadexV1Pool__ZeroLpTokensToMint();

        _mint(_receiver, lpTokensToMint);
        _updateReserves(balanceA, balanceB);
        emit LiquidityAdded(msg.sender, _receiver, amountAIn, amountBIn, lpTokensToMint);

        return lpTokensToMint;
    }

    function removeLiquidity(address _receiver) external globalLock returns (uint256, uint256) {
        (address tokenA, address tokenB) = getPoolTokens();
        uint256 balanceA = IERC20(tokenA).balanceOf(address(this));
        uint256 balanceB = IERC20(tokenB).balanceOf(address(this));
        uint256 lpTokensReceived = balanceOf(address(this));
        uint256 totalLpTokenSupply = totalSupply();

        uint256 amountAOut = (lpTokensReceived * balanceA) / totalLpTokenSupply;
        uint256 amountBOut = (lpTokensReceived * balanceB) / totalLpTokenSupply;
        if (amountAOut == 0 || amountBOut == 0) {
            revert MonadexV1Pool__CannotWithdrawZeroTokenAmount();
        }
        _burn(address(this), lpTokensReceived);
        IERC20(tokenA).safeTransfer(_receiver, amountAOut);
        IERC20(tokenB).safeTransfer(_receiver, amountBOut);
        balanceA = IERC20(tokenA).balanceOf(address(this));
        balanceB = IERC20(tokenB).balanceOf(address(this));
        _updateReserves(balanceA, balanceB);
        emit LiquidityRemoved(msg.sender, _receiver, amountAOut, amountBOut, lpTokensReceived);

        return (amountAOut, amountBOut);
    }

    function syncBalancesBasedOnReserves(address _receiver) external globalLock {
        address tokenA = s_tokenA;
        address tokenB = s_tokenB;
        IERC20(tokenA).safeTransfer(_receiver, IERC20(tokenA).balanceOf(address(this)) - s_reserveA);
        IERC20(tokenB).safeTransfer(_receiver, IERC20(tokenB).balanceOf(address(this)) - s_reserveB);
    }

    function syncReservesBasedOnBalances() external globalLock {
        _updateReserves(
            IERC20(s_tokenA).balanceOf(address(this)), IERC20(s_tokenB).balanceOf(address(this))
        );
    }

    function setProtocolTeamMultisig(address _protocolTeamMultisig) external onlyOwner {
        s_protocolTeamMultisig = _protocolTeamMultisig;
        emit ProtocolTeamMultisigSet(_protocolTeamMultisig);
    }

    function setProtocolFee(MonadexV1Types.Fee memory _protocolFee) external onlyOwner {
        s_protocolFee = _protocolFee;
        emit ProtocolFeeSet(_protocolFee);
    }

    function getProtocolTeamMultisig() external view returns (address) {
        return s_protocolTeamMultisig;
    }

    function getProtocolFee() external view returns (MonadexV1Types.Fee memory) {
        return s_protocolFee;
    }

    function getPoolFee() external view returns (MonadexV1Types.Fee memory) {
        return s_poolFee;
    }

    function isPoolToken(address _token) public view returns (bool) {
        if (_token != s_tokenA || _token != s_tokenB) return false;
        return true;
    }

    function getPoolTokens() public view returns (address, address) {
        return (s_tokenA, s_tokenB);
    }

    function getReserves() public view returns (uint256, uint256) {
        return (s_reserveA, s_reserveB);
    }

    function _updateReserves(uint256 _reserveA, uint256 _reserveB) internal {
        s_reserveA = _reserveA;
        s_reserveB = _reserveB;

        emit ReservesUpdated(_reserveA, _reserveB);
    }

    function _sendFeeToProtocolTeamMultisig(address _token, uint256 _amount) internal {
        IERC20(_token).safeTransfer(s_protocolTeamMultisig, _amount);
    }
}
