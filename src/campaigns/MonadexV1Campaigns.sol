// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { Owned } from "@solmate/auth/Owned.sol";

import { ILaunch } from "../interfaces/ILaunch.sol";
import { IMonadexV1Campaigns } from "../interfaces/IMonadexV1Campaigns.sol";
import { IMonadexV1Router } from "../interfaces/IMonadexV1Router.sol";
import { IOwned } from "../interfaces/IOwned.sol";
import { IWNative } from "../interfaces/IWNative.sol";

import { MonadexV1Library } from "../library/MonadexV1Library.sol";
import { MonadexV1Types } from "../library/MonadexV1Types.sol";
import { ERC20Launchable } from "./ERC20Launchable.sol";

contract MonadexV1Campaigns is Owned, IMonadexV1Campaigns {
    using SafeERC20 for IERC20;

    address private constant ZERO_ADDRESS = address(0);

    uint256 private s_minimumTokenTotalSupply;
    uint256 private s_minimumVirutalNativeReserve;
    uint256 private s_minimumNativeAmountToRaise;

    uint256 private s_tokenCreatorReward;
    uint256 private s_liquidityMigrationFee;

    MonadexV1Types.Fee private s_fee;
    uint256 private s_feeCollected;

    address private immutable i_monadexV1Router;
    address private immutable i_wNative;
    address private s_vault;

    uint256 private s_tokenCounter;
    mapping(uint256 tokenCount => address token) private s_tokenCountToTokenAddress;
    mapping(address token => MonadexV1Types.TokenDetails tokenDetails) private s_tokenDetails;

    event MinimumTokenTotalSupplySet(uint256 indexed newMinimumTokenTotalSupply);
    event MinimumVirtualNativeReserveSet(uint256 indexed newMinimumVirtualNativeReserve);
    event MinimumNativeAmountToRaiseSet(uint256 indexed newMinimumNativeAmountToRaise);
    event TokenCreatorRewardSet(uint256 indexed newTokenCreatorReward);
    event LiquidityMigrationFeeSet(uint256 indexed newLiquidityMigrationFee);
    event FeeSet(MonadexV1Types.Fee indexed newFee);
    event VaultSet(address indexed newVault);
    event FeesCollected(address indexed by, uint256 indexed amount, address indexed to);
    event TokenCreated(address indexed token, MonadexV1Types.TokenDetails indexed tokenDetails);
    event TokensSold(
        address indexed by,
        address indexed token,
        uint256 indexed amount,
        address nativeAmountRecipient
    );
    event TokensBought(
        address by, address indexed token, uint256 indexed amount, address indexed receiver
    );
    event BondingCurveCompleted(address indexed token);

    error MonadexV1Campaigns__DeadlinePasssed(uint256 deadline);
    error MonadexV1Campaigns__InsufficientFeesToCollect();
    error MonadexV1Campaigns__TransferFailed();
    error MonadexV1Campaigns__InvalidTokenCreationparams(MonadexV1Types.TokenDetails tokenDetails);
    error MonadexV1Campaigns__TokenAmountOutLessThanMinimumAmountOut(
        uint256 amountOut, uint256 minimumAmountOut
    );
    error MonadexV1Campaigns__BondingCurveBreached(uint256 target, uint256 currentReserve);

    modifier beforeDeadline(uint256 _deadline) {
        if (_deadline < block.timestamp) revert MonadexV1Campaigns__DeadlinePasssed(_deadline);
        _;
    }

    constructor(
        uint256 _minimumTokenTotalSupply,
        uint256 _minimumVirutalNativeReserve,
        uint256 _minimumNativeAmountToRaise,
        MonadexV1Types.Fee memory _fee,
        uint256 _tokenCreatorReward,
        uint256 _liquidityMigrationFee,
        address _monadexV1Router,
        address _wNative,
        address _vault
    )
        Owned(msg.sender)
    {
        s_minimumTokenTotalSupply = _minimumTokenTotalSupply;
        s_minimumVirutalNativeReserve = _minimumVirutalNativeReserve;
        s_minimumNativeAmountToRaise = _minimumNativeAmountToRaise;
        s_fee = _fee;
        s_tokenCreatorReward = _tokenCreatorReward;
        s_liquidityMigrationFee = _liquidityMigrationFee;
        i_monadexV1Router = _monadexV1Router;
        i_wNative = _wNative;
        s_vault = _vault;
    }

    function setMinimumTokenTotalSupply(uint256 _minimumTokenTotalSupply) external onlyOwner {
        s_minimumTokenTotalSupply = _minimumTokenTotalSupply;

        emit MinimumTokenTotalSupplySet(_minimumTokenTotalSupply);
    }

    function setMinimumVirtualNativeReserve(
        uint256 _minimumVirtualNativeReserve
    )
        external
        onlyOwner
    {
        s_minimumVirutalNativeReserve = _minimumVirtualNativeReserve;

        emit MinimumVirtualNativeReserveSet(_minimumVirtualNativeReserve);
    }

    function setMinimumNativeAmountToRaise(
        uint256 _minimumNativeAmountToRaise
    )
        external
        onlyOwner
    {
        s_minimumNativeAmountToRaise = _minimumNativeAmountToRaise;

        emit MinimumNativeAmountToRaiseSet(_minimumNativeAmountToRaise);
    }

    function setTokenCreatorReward(uint256 _tokenCreatorReward) external onlyOwner {
        s_tokenCreatorReward = _tokenCreatorReward;

        emit TokenCreatorRewardSet(_tokenCreatorReward);
    }

    function setLiquidityMigrationFee(uint256 _liquidityMigrationFee) external onlyOwner {
        s_liquidityMigrationFee = _liquidityMigrationFee;
    }

    function setFee(MonadexV1Types.Fee memory _fee) external onlyOwner {
        s_fee = _fee;

        emit FeeSet(_fee);
    }

    function setVault(address _vault) external onlyOwner {
        s_vault = _vault;

        emit VaultSet(_vault);
    }

    function collectFees(address _to, uint256 _amount) external onlyOwner {
        if (_amount > s_feeCollected) revert MonadexV1Campaigns__InsufficientFeesToCollect();
        s_feeCollected -= _amount;

        (bool success,) = payable(_to).call{ value: _amount }("");
        if (!success) revert MonadexV1Campaigns__TransferFailed();

        emit FeesCollected(msg.sender, _amount, _to);
    }

    function createToken(
        MonadexV1Types.TokenDetails calldata _tokenDetails,
        uint256 _deadline
    )
        external
        payable
        beforeDeadline(_deadline)
        returns (address)
    {
        if (
            _tokenDetails.creator != msg.sender
                || _tokenDetails.tokenReserve < s_minimumTokenTotalSupply
                || _tokenDetails.nativeReserve < s_minimumVirutalNativeReserve
                || _tokenDetails.virtualNativeReserve != _tokenDetails.nativeReserve
                || _tokenDetails.targetNativeReserve - _tokenDetails.virtualNativeReserve
                    < s_minimumNativeAmountToRaise
                || _tokenDetails.tokenCreatorReward != s_tokenCreatorReward
                || _tokenDetails.liquidityMigrationFee != s_liquidityMigrationFee
        ) revert MonadexV1Campaigns__InvalidTokenCreationparams(_tokenDetails);

        ERC20Launchable token = new ERC20Launchable(
            _tokenDetails.name, _tokenDetails.symbol, _tokenDetails.tokenReserve
        );
        uint256 count = s_tokenCounter++;
        s_tokenCountToTokenAddress[count] = address(token);
        s_tokenDetails[address(token)] = _tokenDetails;

        emit TokenCreated(address(token), _tokenDetails);

        buyTokens(address(token), 0, _deadline, msg.sender);

        return address(token);
    }

    function sellTokens(
        address _token,
        uint256 _amount,
        uint256 _minimumWrappedNativeAmountToReceive,
        uint256 _deadline,
        address _receiver
    )
        external
        beforeDeadline(_deadline)
    {
        MonadexV1Types.TokenDetails memory tokenDetails = s_tokenDetails[_token];
        (uint256 nativeAmount, uint256 fee) = previewSell(_token, _amount);
        if (nativeAmount < _minimumWrappedNativeAmountToReceive) {
            revert MonadexV1Campaigns__TokenAmountOutLessThanMinimumAmountOut(
                nativeAmount, _minimumWrappedNativeAmountToReceive
            );
        }

        s_feeCollected += fee;
        s_tokenDetails[_token].nativeReserve -= nativeAmount + fee;
        s_tokenDetails[_token].tokenReserve += _amount;

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        IWNative(payable(i_wNative)).deposit{ value: nativeAmount }();
        IERC20(i_wNative).safeTransfer(_receiver, nativeAmount);

        emit TokensSold(msg.sender, _token, _amount, _receiver);
    }

    function buyTokens(
        address _token,
        uint256 _minimumAmountToReceive,
        uint256 _deadline,
        address _receiver
    )
        public
        payable
        beforeDeadline(_deadline)
    {
        MonadexV1Types.TokenDetails memory tokenDetails = s_tokenDetails[_token];

        (uint256 tokenAmount, uint256 feeAmount) = previewBuy(_token, msg.value);
        if (tokenAmount < _minimumAmountToReceive) {
            revert MonadexV1Campaigns__TokenAmountOutLessThanMinimumAmountOut(
                tokenAmount, _minimumAmountToReceive
            );
        }
        s_tokenDetails[_token].nativeReserve += msg.value - feeAmount;
        s_tokenDetails[_token].tokenReserve -= tokenAmount;
        IERC20(_token).safeTransfer(_receiver, tokenAmount);

        emit TokensBought(msg.sender, _token, tokenAmount, _receiver);

        if (
            tokenDetails.nativeReserve
                > tokenDetails.targetNativeReserve + tokenDetails.tokenCreatorReward
                    + tokenDetails.liquidityMigrationFee
        ) {
            revert MonadexV1Campaigns__BondingCurveBreached(
                tokenDetails.targetNativeReserve + tokenDetails.tokenCreatorReward
                    + tokenDetails.liquidityMigrationFee,
                tokenDetails.nativeReserve
            );
        }
        if (
            tokenDetails.nativeReserve
                == tokenDetails.targetNativeReserve + tokenDetails.tokenCreatorReward
                    + tokenDetails.liquidityMigrationFee
        ) {
            _completeBondingCurve(_token, tokenDetails, _deadline);
        }
    }

    function _completeBondingCurve(
        address _token,
        MonadexV1Types.TokenDetails memory _tokenDetails,
        uint256 _deadline
    )
        internal
    {
        MonadexV1Types.AddLiquidityNative memory addLiquidityNativeParams = MonadexV1Types
            .AddLiquidityNative({
            token: _token,
            amountTokenDesired: _tokenDetails.tokenReserve,
            amountTokenMin: 0,
            amountNativeTokenMin: 0,
            receiver: s_vault,
            deadline: _deadline
        });
        IMonadexV1Router(i_monadexV1Router).addLiquidityNative{
            value: _tokenDetails.nativeReserve - _tokenDetails.virtualNativeReserve
                - _tokenDetails.tokenCreatorReward - _tokenDetails.liquidityMigrationFee
        }(addLiquidityNativeParams);

        IWNative(payable(i_wNative)).deposit{ value: _tokenDetails.tokenCreatorReward }();
        IERC20(i_wNative).safeTransfer(_tokenDetails.creator, _tokenDetails.tokenCreatorReward);
        s_feeCollected += _tokenDetails.liquidityMigrationFee;

        ILaunch(_token).launch();
        IOwned(_token).transferOwnership(ZERO_ADDRESS);

        emit BondingCurveCompleted(_token);
    }

    function getMinimumTokenTotalSupply() external view returns (uint256) {
        return s_minimumTokenTotalSupply;
    }

    function getMinimumVirutalNativeReserve() external view returns (uint256) {
        return s_minimumVirutalNativeReserve;
    }

    function getMinimumNativeAmountToRaise() external view returns (uint256) {
        return s_minimumNativeAmountToRaise;
    }

    function getTokenCreatorReward() external view returns (uint256) {
        return s_tokenCreatorReward;
    }

    function getLiquidityMigrationFee() external view returns (uint256) {
        return s_liquidityMigrationFee;
    }

    function getFee() external view returns (MonadexV1Types.Fee memory) {
        return s_fee;
    }

    function getFeeCollected() external view returns (uint256) {
        return s_feeCollected;
    }

    function getMonadexV1Router() external view returns (address) {
        return i_monadexV1Router;
    }

    function getWNative() external view returns (address) {
        return i_wNative;
    }

    function getVault() external view returns (address) {
        return s_vault;
    }

    function previewBuy(
        address _token,
        uint256 _nativeAmount
    )
        public
        view
        returns (uint256, uint256)
    {
        MonadexV1Types.TokenDetails memory tokenDetails = s_tokenDetails[_token];

        uint256 nativeAmountAfterFee =
            MonadexV1Library.calculateBuyAmountAfterFeeForCampaigns(_nativeAmount, s_fee);
        uint256 tokenAmount = MonadexV1Library.getAmountOutForCampaigns(
            nativeAmountAfterFee, tokenDetails.nativeReserve, tokenDetails.tokenReserve
        );

        return (tokenAmount, _nativeAmount - nativeAmountAfterFee);
    }

    function previewSell(
        address _token,
        uint256 _tokenAmount
    )
        public
        view
        returns (uint256, uint256)
    {
        MonadexV1Types.TokenDetails memory tokenDetails = s_tokenDetails[_token];

        uint256 nativeAmountToSend = MonadexV1Library.getAmountOutForCampaigns(
            _tokenAmount, tokenDetails.tokenReserve, tokenDetails.nativeReserve
        );
        uint256 fee =
            MonadexV1Library.calculateAmountAfterApplyingPercentage(nativeAmountToSend, s_fee);

        return (nativeAmountToSend - fee, fee);
    }
}
