// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Owned } from "@solmate/auth/Owned.sol";

import { IBubbleV1Campaigns } from "@src/interfaces/IBubbleV1Campaigns.sol";
import { IBubbleV1Router } from "@src/interfaces/IBubbleV1Router.sol";
import { ILaunch } from "@src/interfaces/ILaunch.sol";
import { IOwned } from "@src/interfaces/IOwned.sol";
import { IWNative } from "@src/interfaces/IWNative.sol";

import { ERC20Launchable } from "@src/campaigns/ERC20Launchable.sol";
import { BubbleV1Library } from "@src/library/BubbleV1Library.sol";
import { BubbleV1Types } from "@src/library/BubbleV1Types.sol";

/// @title BubbleV1Campaigns.
/// @author Bubble Finance -- mgnfy-view.
/// @notice The core campaigns contract that facilitates the creation and launch of new tokens
/// with custom bonding curve parameters. Once these tokens complete their bonding curves, the raised
/// liquidity is added to Bubble, and both the protocol and token creator receive rewards. The contract
/// removes transfer restrictions from the launched token, and renounces ownership of the token contract.
contract BubbleV1Campaigns is Owned, IBubbleV1Campaigns {
    using SafeERC20 for IERC20;

    ///////////////////////
    /// State Variables ///
    ///////////////////////

    /// @dev The minimum total supply each newly created token should have.
    uint256 private s_minimumTokenTotalSupply;
    /// @dev The minimum initial virtual native token amount each token's bonding curve
    /// should start with.
    uint256 private s_minimumVirutalNativeTokenReserve;
    /// @dev The minimum native token amount to raise in each bonding curve.
    uint256 private s_minimumNativeTokenAmountToRaise;
    /// @dev The reward in wrapped native token a token creator is eligible for once
    /// a token successfully completes its bonding curve.
    uint256 private s_tokenCreatorReward;
    /// @dev The fee taken in native token by the protocol once
    /// a token successfully completes its bonding curve.
    uint256 private s_liquidityMigrationFee;
    /// @dev The percentage fee taken by the protocol for each buy/sell amount.
    BubbleV1Types.Fraction private s_fee;
    /// @dev The amount of native token collected in fees by the protocol.
    uint256 private s_feeCollected;
    /// @dev The address of the BubbleV1Router.
    address private immutable i_bubbleV1Router;
    /// @dev The address of the wrapped native token.
    address private immutable i_wNative;
    /// @dev The address of the proxy owned by the DAO which will use the LP tokens
    /// for farming rewards for the Bubble token holders.
    address private s_vault;
    /// @dev A counter which tracks the total number of tokens created so far.
    uint256 private s_tokenCounter;
    /// @dev An array implementation using a mapping which stores addresses of all tokens
    /// created so far.
    mapping(uint256 tokenCount => address token) private s_tokenCountToTokenAddress;
    /// @dev Maps a token address to its details which includes token metadata and bonding
    /// curve details.
    mapping(address token => BubbleV1Types.TokenDetails tokenDetails) private s_tokenDetails;

    //////////////
    /// Events ///
    //////////////

    event MinimumTokenTotalSupplySet(uint256 indexed newMinimumTokenTotalSupply);
    event MinimumVirtualNativeTokenReserveSet(uint256 indexed newMinimumVirtualNativeReserve);
    event MinimumNativeTokenAmountToRaiseSet(uint256 indexed newMinimumNativeAmountToRaise);
    event TokenCreatorRewardSet(uint256 indexed newTokenCreatorReward);
    event LiquidityMigrationFeeSet(uint256 indexed newLiquidityMigrationFee);
    event FeeSet(BubbleV1Types.Fraction indexed newFee);
    event VaultSet(address indexed newVault);
    event FeesCollected(address indexed by, uint256 indexed amount, address indexed to);
    event TokenCreated(address indexed token, BubbleV1Types.TokenDetails indexed tokenDetails);
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

    //////////////
    /// Errors ///
    //////////////

    error BubbleV1Campaigns__DeadlinePasssed(uint256 deadline);
    error BubbleV1Campaigns__AmountZero();
    error BubbleV1Campaigns__AddressZero();
    error BubbleV1Campaigns__InvalidFee(BubbleV1Types.Fraction fee);
    error BubbleV1Campaigns__InsufficientFeesToCollect(
        uint256 amountToCollect, uint256 accumulatedFees
    );
    error BubbleV1Campaigns__InvalidTokenCreationparams(BubbleV1Types.TokenDetails tokenDetails);
    error BubbleV1Campaigns__BondingCurveNotActive();
    error BubbleV1Campaigns__TokenAmountOutLessThanMinimumAmountOut(
        uint256 amountOut, uint256 minimumAmountOut
    );

    modifier beforeDeadline(uint256 _deadline) {
        if (_deadline < block.timestamp) revert BubbleV1Campaigns__DeadlinePasssed(_deadline);
        _;
    }

    ///////////////////
    /// Constructor ///
    ///////////////////

    /// @notice Initializes the campaigns contract.
    /// @param _minimumTokenTotalSupply The minimum total supply each newly created token should have.
    /// @param _minimumVirutalNativeTokenReserve The minimum initial virtual native token amount each
    /// token's bonding curve should start with.
    /// @param _minimumNativeTokenAmountToRaise The minimum native token amount to raise in each binding curve.
    /// @param _fee The percentage fee taken by the protocol for each buy/sell amount.
    /// @param _tokenCreatorReward The reward in wrapped native token a token creator is eligible for once
    /// a token successfully completes its bonding curve.
    /// @param _liquidityMigrationFee The fee taken in native token by the protocol once
    /// a token successfully completes its bonding curve.
    /// @param _bubbleV1Router The address of the BubbleV1Router.
    /// @param _wNative The address of the wrapped native token.
    /// @param _vault The address of the proxy owned by the DAO which will use the LP tokens
    /// for farming rewards for the Bubble token holders.
    constructor(
        uint256 _minimumTokenTotalSupply,
        uint256 _minimumVirutalNativeTokenReserve,
        uint256 _minimumNativeTokenAmountToRaise,
        BubbleV1Types.Fraction memory _fee,
        uint256 _tokenCreatorReward,
        uint256 _liquidityMigrationFee,
        address _bubbleV1Router,
        address _wNative,
        address _vault
    )
        Owned(msg.sender)
    {
        if (
            _minimumTokenTotalSupply == 0 || _minimumVirutalNativeTokenReserve == 0
                || _minimumNativeTokenAmountToRaise == 0
        ) revert BubbleV1Campaigns__AmountZero();
        if (_bubbleV1Router == address(0) || _wNative == address(0) || _vault == address(0)) {
            revert BubbleV1Campaigns__AddressZero();
        }

        s_minimumTokenTotalSupply = _minimumTokenTotalSupply;
        s_minimumVirutalNativeTokenReserve = _minimumVirutalNativeTokenReserve;
        s_minimumNativeTokenAmountToRaise = _minimumNativeTokenAmountToRaise;
        s_fee = _fee;
        s_tokenCreatorReward = _tokenCreatorReward;
        s_liquidityMigrationFee = _liquidityMigrationFee;
        i_bubbleV1Router = _bubbleV1Router;
        i_wNative = _wNative;
        s_vault = _vault;
    }

    //////////////////////////
    /// External Functions ///
    //////////////////////////

    /// @notice Allows the owner to set the minimum total supply for each newly created token.
    /// @param _minimumTokenTotalSupply The new minimum total supply for each newly created token.
    function setMinimumTokenTotalSupply(uint256 _minimumTokenTotalSupply) external onlyOwner {
        if (_minimumTokenTotalSupply == 0) revert BubbleV1Campaigns__AmountZero();

        s_minimumTokenTotalSupply = _minimumTokenTotalSupply;

        emit MinimumTokenTotalSupplySet(_minimumTokenTotalSupply);
    }

    /// @notice Allows the owner to set the minimum virtual native token reserve for each newly created token.
    /// @param _minimumVirtualNativeTokenReserve The new minimum virtual native token reserve.
    function setMinimumVirtualNativeTokenReserve(
        uint256 _minimumVirtualNativeTokenReserve
    )
        external
        onlyOwner
    {
        if (_minimumVirtualNativeTokenReserve == 0) revert BubbleV1Campaigns__AmountZero();

        s_minimumVirutalNativeTokenReserve = _minimumVirtualNativeTokenReserve;

        emit MinimumVirtualNativeTokenReserveSet(_minimumVirtualNativeTokenReserve);
    }

    /// @notice Allows the owner to change the minimum native token amount to raise for
    /// each newly created token.
    /// @param _minimumNativeTokenAmountToRaise The new minimum native token amount to raise.
    function setMinimumNativeTokenAmountToRaise(
        uint256 _minimumNativeTokenAmountToRaise
    )
        external
        onlyOwner
    {
        if (_minimumNativeTokenAmountToRaise == 0) revert BubbleV1Campaigns__AmountZero();

        s_minimumNativeTokenAmountToRaise = _minimumNativeTokenAmountToRaise;

        emit MinimumNativeTokenAmountToRaiseSet(_minimumNativeTokenAmountToRaise);
    }

    /// @notice Allows the owner to change the reward the token creator is eligible for when the
    /// token completes its bonding curve.
    /// @param _tokenCreatorReward The new reward the token creator is eligible for when the
    /// token completes its bonding curve.
    function setTokenCreatorReward(uint256 _tokenCreatorReward) external onlyOwner {
        s_tokenCreatorReward = _tokenCreatorReward;

        emit TokenCreatorRewardSet(_tokenCreatorReward);
    }

    /// @notice Allows the owner to change the fee taken when liquidity is added to Bubble.
    /// @param _liquidityMigrationFee The new fee taken when the token completes its bonding curve.
    function setLiquidityMigrationFee(uint256 _liquidityMigrationFee) external onlyOwner {
        s_liquidityMigrationFee = _liquidityMigrationFee;

        emit LiquidityMigrationFeeSet(_liquidityMigrationFee);
    }

    /// @notice Allows the owner to change the fee taken while buying/selling tokens.
    /// @param _fee The new fee while buying/selling tokens.
    function setFee(BubbleV1Types.Fraction memory _fee) external onlyOwner {
        if (_fee.denominator == 0 || _fee.numerator > _fee.denominator) {
            revert BubbleV1Campaigns__InvalidFee(_fee);
        }

        s_fee = _fee;

        emit FeeSet(_fee);
    }

    /// @notice Allows the owner to change the vault address where LP tokens are directed to
    /// once a token completes its bonding curve.
    /// @param _vault The new vault address.
    function setVault(address _vault) external onlyOwner {
        if (_vault == address(0)) revert BubbleV1Campaigns__AddressZero();

        s_vault = _vault;

        emit VaultSet(_vault);
    }

    /// @notice Allows the owner to withdraw fees (in native token) collected by the protocol.
    /// @param _to The address to which the fee amount is directed to.
    /// @param _amount The amount of native token to withdraw.
    function collectFees(address _to, uint256 _amount) external onlyOwner {
        if (_to == address(0)) revert BubbleV1Campaigns__AddressZero();
        if (_amount > s_feeCollected) {
            revert BubbleV1Campaigns__InsufficientFeesToCollect(_amount, s_feeCollected);
        }

        s_feeCollected -= _amount;
        _safeTransferNativeWithFallback(_to, _amount);

        emit FeesCollected(msg.sender, _amount, _to);
    }

    /// @notice Allows anyone to create a token with custom parameters, and start a fund raising camapign.
    /// @param _tokenDetails The associated token details which includes token metadata
    /// and bonding curve details.
    /// @param _deadline The deadline before which the token should be created.
    /// @param _initialNativeAmountToBuyWith The native token amount to be used for initial token purchase.
    /// @return Address of the created token.
    function createToken(
        BubbleV1Types.TokenDetails calldata _tokenDetails,
        uint256 _deadline,
        uint256 _initialNativeAmountToBuyWith
    )
        external
        payable
        returns (address)
    {
        if (
            _tokenDetails.creator != msg.sender
                || _tokenDetails.tokenReserve < s_minimumTokenTotalSupply
                || _tokenDetails.nativeTokenReserve < s_minimumVirutalNativeTokenReserve
                || _tokenDetails.virtualNativeTokenReserve != _tokenDetails.nativeTokenReserve
                || _tokenDetails.targetNativeTokenReserve - _tokenDetails.virtualNativeTokenReserve
                    < s_minimumNativeTokenAmountToRaise
                || _tokenDetails.tokenCreatorReward != s_tokenCreatorReward
                || _tokenDetails.liquidityMigrationFee != s_liquidityMigrationFee
                || _tokenDetails.launched == true
        ) revert BubbleV1Campaigns__InvalidTokenCreationparams(_tokenDetails);

        ERC20Launchable token = new ERC20Launchable(
            _tokenDetails.name, _tokenDetails.symbol, _tokenDetails.tokenReserve
        );
        uint256 count = s_tokenCounter++;
        s_tokenCountToTokenAddress[count] = address(token);
        s_tokenDetails[address(token)] = _tokenDetails;

        emit TokenCreated(address(token), _tokenDetails);

        buyTokens(address(token), _initialNativeAmountToBuyWith, 0, _deadline, msg.sender);

        return address(token);
    }

    /// @notice Allows a user to sell tokens on an active bonding curve.
    /// @param _token The token to sell.
    /// @param _amount The amount of tokens to sell.
    /// @param _minimumWrappedNativeAmountToReceive The minimum amount of wrapped native token to receive
    /// on selling the token.
    /// @param _deadline The UNIX timestamp before which the tokens should be sold.
    /// @param _receiver The recipient of the wrapped native token.
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
        if (_token == address(0) || _receiver == address(0)) {
            revert BubbleV1Campaigns__AddressZero();
        }
        if (_amount == 0) revert BubbleV1Campaigns__AmountZero();

        BubbleV1Types.TokenDetails memory tokenDetails = s_tokenDetails[_token];
        if (tokenDetails.launched) revert BubbleV1Campaigns__BondingCurveNotActive();

        (uint256 nativeAmount, uint256 fee) = previewSell(_token, _amount);
        if (nativeAmount < _minimumWrappedNativeAmountToReceive) {
            revert BubbleV1Campaigns__TokenAmountOutLessThanMinimumAmountOut(
                nativeAmount, _minimumWrappedNativeAmountToReceive
            );
        }

        s_feeCollected += fee;
        s_tokenDetails[_token].nativeTokenReserve -= nativeAmount + fee;
        s_tokenDetails[_token].tokenReserve += _amount;

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        _safeTransferNativeWithFallback(_receiver, nativeAmount);

        emit TokensSold(msg.sender, _token, _amount, _receiver);
    }

    /// @notice Allows a user to buy tokens on an active bonding curve.
    /// @param _token The token to sell.
    /// @param _nativeTokenAmount The native token amount to use for purchase.
    /// @param _minimumAmountToReceive The minimum amount of tokens to receive
    /// on buying.
    /// @param _deadline The UNIX timestamp before which the tokens should be bought.
    /// @param _receiver The recipient of the token.
    function buyTokens(
        address _token,
        uint256 _nativeTokenAmount,
        uint256 _minimumAmountToReceive,
        uint256 _deadline,
        address _receiver
    )
        public
        payable
        beforeDeadline(_deadline)
    {
        if (_token == address(0) || _receiver == address(0)) {
            revert BubbleV1Campaigns__AddressZero();
        }

        BubbleV1Types.TokenDetails memory tokenDetails = s_tokenDetails[_token];
        if (tokenDetails.launched) revert BubbleV1Campaigns__BondingCurveNotActive();
        uint256 nativeTokenAmountToCompleteBondingCurve =
            getRemainingNativeTokenAmountToCompleteBondingCurve(_token);
        uint256 refundAmount;
        bool completeBondingCurve;
        uint256 tokenAmount;
        uint256 feeAmount;
        if (nativeTokenAmountToCompleteBondingCurve <= _nativeTokenAmount) {
            _nativeTokenAmount = nativeTokenAmountToCompleteBondingCurve;
            completeBondingCurve = true;
        }
        (tokenAmount, feeAmount) = previewBuy(_token, _nativeTokenAmount);
        refundAmount = msg.value - _nativeTokenAmount - feeAmount;
        if (tokenAmount < _minimumAmountToReceive) {
            revert BubbleV1Campaigns__TokenAmountOutLessThanMinimumAmountOut(
                tokenAmount, _minimumAmountToReceive
            );
        }

        s_feeCollected += feeAmount;
        s_tokenDetails[_token].nativeTokenReserve += _nativeTokenAmount;
        s_tokenDetails[_token].tokenReserve -= tokenAmount;
        IERC20(_token).safeTransfer(_receiver, tokenAmount);
        if (refundAmount > 0) _safeTransferNativeWithFallback(msg.sender, refundAmount);

        emit TokensBought(msg.sender, _token, tokenAmount, _receiver);

        if (completeBondingCurve) {
            _completeBondingCurve(_token, tokenDetails, _deadline);
        }
    }

    //////////////////////////
    /// Internal Functions ///
    //////////////////////////

    /// @notice Adds the raised liquidity and remainging tokens to Bubble.
    /// @param _token The token address.
    /// @param _tokenDetails The metadata and bonding curve details of the token.
    /// @param _deadline The UNIX timestamp before which the tokens should be added to Bubble.
    function _completeBondingCurve(
        address _token,
        BubbleV1Types.TokenDetails memory _tokenDetails,
        uint256 _deadline
    )
        internal
    {
        BubbleV1Types.AddLiquidityNative memory addLiquidityNativeParams = BubbleV1Types
            .AddLiquidityNative({
            token: _token,
            amountTokenDesired: _tokenDetails.tokenReserve,
            amountTokenMin: 0,
            amountNativeTokenMin: 0,
            receiver: s_vault,
            deadline: _deadline
        });
        IERC20(_token).approve(i_bubbleV1Router, _tokenDetails.tokenReserve);
        IBubbleV1Router(i_bubbleV1Router).addLiquidityNative{
            value: _tokenDetails.nativeTokenReserve - _tokenDetails.virtualNativeTokenReserve
                - _tokenDetails.tokenCreatorReward - _tokenDetails.liquidityMigrationFee
        }(addLiquidityNativeParams);

        _safeTransferNativeWithFallback(_tokenDetails.creator, _tokenDetails.tokenCreatorReward);
        s_feeCollected += _tokenDetails.liquidityMigrationFee;

        s_tokenDetails[_token].launched = true;
        ILaunch(_token).launch();
        IOwned(_token).transferOwnership(address(0));

        emit BondingCurveCompleted(_token);
    }

    /// @notice Transfers native token to the given user, and if it fails, transfers the wrapped native tokens
    /// to the user.
    /// @param _to The address to transfer the native token/wrapped native tokens to.
    /// @param _amount The amount of native token/wrapped native tokens to transfer.
    function _safeTransferNativeWithFallback(address _to, uint256 _amount) internal {
        (bool success,) = payable(_to).call{ value: _amount }("");
        if (!success) {
            IWNative(payable(i_wNative)).deposit{ value: _amount }();
            IERC20(i_wNative).safeTransfer(_to, _amount);
        }
    }

    ///////////////////////////////
    /// View and Pure Functions ///
    ///////////////////////////////

    /// @notice Gets the minimum token total supply for any newly launched token.
    /// @return The minimum token total supply.
    function getMinimumTokenTotalSupply() external view returns (uint256) {
        return s_minimumTokenTotalSupply;
    }

    /// @notice Gets the minimum virtual native reserve for any newly launched token.
    /// @return The minimum virtual native reserve.
    function getMinimumVirutalNativeReserve() external view returns (uint256) {
        return s_minimumVirutalNativeTokenReserve;
    }

    /// @notice Gets the minimum native amount to raise for any newly launched token.
    /// @return The minimum native amount to raise.
    function getMinimumNativeAmountToRaise() external view returns (uint256) {
        return s_minimumNativeTokenAmountToRaise;
    }

    /// @notice Gets the reward a token creator is eligible for when the token successfully
    /// completes its bonding curve.
    /// @return The token creator's reward in wrapped native token.
    function getTokenCreatorReward() external view returns (uint256) {
        return s_tokenCreatorReward;
    }

    /// @notice Gets the fee taken by the protocol on each successful bonding curve completion.
    /// @return The liqudity migration fee.
    function getLiquidityMigrationFee() external view returns (uint256) {
        return s_liquidityMigrationFee;
    }

    /// @notice Gets the fee taken by the protocol on each buy/sell amount.
    /// @return The fee struct with numerator and denominator fields.
    function getFee() external view returns (BubbleV1Types.Fraction memory) {
        return s_fee;
    }

    /// @notice Gets the total fee collected by the protocol in native token.
    /// @return The fee collected by the protocol.
    function getFeeCollected() external view returns (uint256) {
        return s_feeCollected;
    }

    /// @notice Gets the address of the BubbleV1Router.
    /// @return The BubbleV1Router address.
    function getBubbleV1Router() external view returns (address) {
        return i_bubbleV1Router;
    }

    /// @notice Gets the address of the wrapped native token.
    /// @return The wrapped native token address.
    function getWNative() external view returns (address) {
        return i_wNative;
    }

    /// @notice Gets the address of the proxy to which the LP tokens from successfully bonded tokens
    /// are directed to.
    /// @return The vault address.
    function getVault() external view returns (address) {
        return s_vault;
    }

    /// @notice Gets the total number of tokens launched so far minus 1.
    /// @return The token counter value.
    function getTokenCounter() external view returns (uint256) {
        return s_tokenCounter;
    }

    /// @notice Gets the token address at the given index.
    /// @param _tokenCount The index value.
    /// @return The address of the token.
    function getTokenCountToToken(uint256 _tokenCount) external view returns (address) {
        return s_tokenCountToTokenAddress[_tokenCount];
    }

    /// @notice Gets the details for a given token.
    /// @param _token The address of the token.
    /// @return The token details.
    function getTokenDetails(
        address _token
    )
        external
        view
        returns (BubbleV1Types.TokenDetails memory)
    {
        return s_tokenDetails[_token];
    }

    function getRemainingNativeTokenAmountToCompleteBondingCurve(
        address _token
    )
        public
        view
        returns (uint256)
    {
        BubbleV1Types.TokenDetails memory tokenDetails = s_tokenDetails[_token];
        if (tokenDetails.launched) return 0;

        return tokenDetails.targetNativeTokenReserve + tokenDetails.tokenCreatorReward
            + tokenDetails.liquidityMigrationFee - tokenDetails.nativeTokenReserve;
    }

    /// @notice Gets the token amount the user will receive and fee to pay in the buy transaction.
    /// @param _token The token address.
    /// @param _nativeAmount The native token amount to use for buying tokens.
    /// @return The token amount to receive.
    /// @return The fee to be paid in native token.
    function previewBuy(
        address _token,
        uint256 _nativeAmount
    )
        public
        view
        returns (uint256, uint256)
    {
        BubbleV1Types.TokenDetails memory tokenDetails = s_tokenDetails[_token];

        uint256 feeAmount =
            BubbleV1Library.calculateAmountAfterApplyingPercentage(_nativeAmount, s_fee);
        uint256 tokenAmount = BubbleV1Library.getAmountOutForCampaigns(
            _nativeAmount, tokenDetails.nativeTokenReserve, tokenDetails.tokenReserve
        );

        return (tokenAmount, feeAmount);
    }

    /// @notice Gets the wrapped native token amount the user will receive and the fee to pay on the
    /// sell transaction.
    /// @param _token The address of the token.
    /// @param _tokenAmount The amount of tokens to sell.
    /// @return The wrapped native amount to receive.
    /// @return The fee to be paid in native token.
    function previewSell(
        address _token,
        uint256 _tokenAmount
    )
        public
        view
        returns (uint256, uint256)
    {
        BubbleV1Types.TokenDetails memory tokenDetails = s_tokenDetails[_token];

        uint256 nativeAmountToSend = BubbleV1Library.getAmountOutForCampaigns(
            _tokenAmount, tokenDetails.tokenReserve, tokenDetails.nativeTokenReserve
        );
        uint256 fee =
            BubbleV1Library.calculateAmountAfterApplyingPercentage(nativeAmountToSend, s_fee);

        return (nativeAmountToSend - fee, fee);
    }
}
