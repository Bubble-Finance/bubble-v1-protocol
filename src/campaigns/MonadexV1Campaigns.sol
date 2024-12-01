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

/// @title MonadexV1Campaigns.
/// @author Monadex Labs -- mgnfy-view.
/// @notice The core campaigns contract that facilitates the creation and launch of new tokens
/// with custom bonding curve parameters. Once these tokens complete their bonding curve, the raised
/// liquidity is added to Monadex, and both the protocol and token creator receive rewards. The contract
/// removes transfer restrictions from the launched token, and renounces ownership of the token contract.
contract MonadexV1Campaigns is Owned, IMonadexV1Campaigns {
    using SafeERC20 for IERC20;

    ///////////////////////
    /// State Variables ///
    ///////////////////////

    /// @dev The zero address constant to transfer the ownership of tokens to.
    address private constant ZERO_ADDRESS = address(0);
    /// @dev The minimum total supply each newly created token should have.
    uint256 private s_minimumTokenTotalSupply;
    /// @dev The minimum initial virtual native currency amount each token's bonding curve
    /// should start with.
    uint256 private s_minimumVirutalNativeReserve;
    /// @dev The minimum native currency amount to raise in each binding curve.
    uint256 private s_minimumNativeAmountToRaise;
    /// @dev The reward in wrapped native token a token creator is eligible for once
    /// a token successfully completes its bonding curve.
    uint256 private s_tokenCreatorReward;
    /// @dev The fee taken in native currency by the protocol once
    /// a token successfully completes its bonding curve.
    uint256 private s_liquidityMigrationFee;
    /// @dev The percentage fee taken by the protocol for each buy/sell amount.
    MonadexV1Types.Fraction private s_fee;
    /// @dev The amount of native currency collected in fees by the protocol.
    uint256 private s_feeCollected;
    /// @dev The address of the MonadexV1Router.
    address private immutable i_monadexV1Router;
    /// @dev The address of the wrapped native token.
    address private immutable i_wNative;
    /// @dev The address of the proxy owned by the DAO which will use the LP tokens
    /// for farming rewards for the MDX token holders.
    address private s_vault;
    /// @dev A counter which tracks the total number of tokens created so far.
    uint256 private s_tokenCounter;
    /// @dev An array implementation using a mapping which stores addresses of all tokens
    /// created so far.
    mapping(uint256 tokenCount => address token) private s_tokenCountToTokenAddress;
    /// @dev Maps a token address to its details which includes token metadata and bonding
    /// curve details.
    mapping(address token => MonadexV1Types.TokenDetails tokenDetails) private s_tokenDetails;

    //////////////
    /// Events ///
    //////////////

    event MinimumTokenTotalSupplySet(uint256 indexed newMinimumTokenTotalSupply);
    event MinimumVirtualNativeReserveSet(uint256 indexed newMinimumVirtualNativeReserve);
    event MinimumNativeAmountToRaiseSet(uint256 indexed newMinimumNativeAmountToRaise);
    event TokenCreatorRewardSet(uint256 indexed newTokenCreatorReward);
    event LiquidityMigrationFeeSet(uint256 indexed newLiquidityMigrationFee);
    event FeeSet(MonadexV1Types.Fraction indexed newFee);
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

    //////////////
    /// Errors ///
    //////////////

    error MonadexV1Campaigns__DeadlinePasssed(uint256 deadline);
    error MonadexV1Campaigns__InsufficientFeesToCollect(
        uint256 amountToCollect, uint256 accumulatedFees
    );
    error MonadexV1Campaigns__TransferFailed();
    error MonadexV1Campaigns__InvalidTokenCreationparams(MonadexV1Types.TokenDetails tokenDetails);
    error MonadexV1Campaigns__BondingCurveNotActive();
    error MonadexV1Campaigns__TokenAmountOutLessThanMinimumAmountOut(
        uint256 amountOut, uint256 minimumAmountOut
    );
    error MonadexV1Campaigns__BondingCurveBreached(uint256 target, uint256 currentReserve);

    modifier beforeDeadline(uint256 _deadline) {
        if (_deadline < block.timestamp) revert MonadexV1Campaigns__DeadlinePasssed(_deadline);
        _;
    }

    ///////////////////
    /// Constructor ///
    ///////////////////

    /// @notice Initializes the campaigns contract.
    /// @param _minimumTokenTotalSupply The minimum total supply each newly created token should have.
    /// @param _minimumVirutalNativeReserve The minimum initial virtual native currency amount each
    /// token's bonding curve should start with.
    /// @param _minimumNativeAmountToRaise The minimum native currency amount to raise in each binding curve.
    /// @param _fee The percentage fee taken by the protocol for each buy/sell amount.
    /// @param _tokenCreatorReward The reward in wrapped native token a token creator is eligible for once
    /// a token successfully completes its bonding curve.
    /// @param _liquidityMigrationFee The fee taken in native currency by the protocol once
    /// a token successfully completes its bonding curve.
    /// @param _monadexV1Router The address of the MonadexV1Router.
    /// @param _wNative The address of the wrapped native token.
    /// @param _vault The address of the proxy owned by the DAO which will use the LP tokens
    /// for farming rewards for the MDX token holders.
    constructor(
        uint256 _minimumTokenTotalSupply,
        uint256 _minimumVirutalNativeReserve,
        uint256 _minimumNativeAmountToRaise,
        MonadexV1Types.Fraction memory _fee,
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

    //////////////////////////
    /// External Functions ///
    //////////////////////////

    /// @notice Allows the owner to set the minimum total supply for each newly created token.
    /// @param _minimumTokenTotalSupply The new minimum total supply for each newly created token.
    function setMinimumTokenTotalSupply(uint256 _minimumTokenTotalSupply) external onlyOwner {
        s_minimumTokenTotalSupply = _minimumTokenTotalSupply;

        emit MinimumTokenTotalSupplySet(_minimumTokenTotalSupply);
    }

    /// @notice Allows the owner to set the minimum virtual native reserve for each newly created token.
    /// @param _minimumVirtualNativeReserve The new minimum virtual native reserve.
    function setMinimumVirtualNativeReserve(
        uint256 _minimumVirtualNativeReserve
    )
        external
        onlyOwner
    {
        s_minimumVirutalNativeReserve = _minimumVirtualNativeReserve;

        emit MinimumVirtualNativeReserveSet(_minimumVirtualNativeReserve);
    }

    /// @notice Allows the owner to change the minimum native currency amount to raise for
    /// each newly created token.
    /// @param _minimumNativeAmountToRaise The new minimum native currency amount to raise.
    function setMinimumNativeAmountToRaise(
        uint256 _minimumNativeAmountToRaise
    )
        external
        onlyOwner
    {
        s_minimumNativeAmountToRaise = _minimumNativeAmountToRaise;

        emit MinimumNativeAmountToRaiseSet(_minimumNativeAmountToRaise);
    }

    /// @notice Allows the owner to change the reward the token creator is eligible for when the
    /// token completes its bonding curve.
    /// @param _tokenCreatorReward The new reward the token creator is eligible for when the
    /// token completes its bonding curve.
    function setTokenCreatorReward(uint256 _tokenCreatorReward) external onlyOwner {
        s_tokenCreatorReward = _tokenCreatorReward;

        emit TokenCreatorRewardSet(_tokenCreatorReward);
    }

    /// @notice Allows the owner to change the fee taken when liquidity is added to Monadex.
    /// @param _liquidityMigrationFee The new fee taken when the token completes its bonding curve.
    function setLiquidityMigrationFee(uint256 _liquidityMigrationFee) external onlyOwner {
        s_liquidityMigrationFee = _liquidityMigrationFee;
    }

    /// @notice Allows the owner to change the fee taken while buying/selling tokens.
    /// @param _fee The new fee while buying/selling tokens.
    function setFee(MonadexV1Types.Fraction memory _fee) external onlyOwner {
        s_fee = _fee;

        emit FeeSet(_fee);
    }

    /// @notice Allows the owner to change the vault address where LP tokens are directed to
    /// once a token completes its bonding curve.
    /// @param _vault The new vault address.
    function setVault(address _vault) external onlyOwner {
        s_vault = _vault;

        emit VaultSet(_vault);
    }

    /// @notice Allows the owner to withdraw fees (in native currency) collected by the protocol.
    /// @param _to The address to which the fee amount is directed to.
    /// @param _amount The amount of native currency to withdraw.
    function collectFees(address _to, uint256 _amount) external onlyOwner {
        if (_amount > s_feeCollected) {
            revert MonadexV1Campaigns__InsufficientFeesToCollect(_amount, s_feeCollected);
        }
        s_feeCollected -= _amount;

        (bool success,) = payable(_to).call{ value: _amount }("");
        if (!success) revert MonadexV1Campaigns__TransferFailed();

        emit FeesCollected(msg.sender, _amount, _to);
    }

    /// @notice Allows anyone to create a token with custom parameters, and start a fund raising camapign.
    /// @param _tokenDetails The associated token details which includes token metadata
    /// and bonding curve details.
    /// @param _deadline The deadline before which the token should be created.
    function createToken(
        MonadexV1Types.TokenDetails calldata _tokenDetails,
        uint256 _deadline
    )
        external
        payable
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
                || _tokenDetails.launched == true
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
        MonadexV1Types.TokenDetails memory tokenDetails = s_tokenDetails[_token];
        if (tokenDetails.launched) revert MonadexV1Campaigns__BondingCurveNotActive();

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

    /// @notice Allows a user to buy tokens on an active bonding curve.
    /// @param _token The token to sell.
    /// @param _minimumAmountToReceive The minimum amount of tokens to receive
    /// on buying.
    /// @param _deadline The UNIX timestamp before which the tokens should be bought.
    /// @param _receiver The recipient of the token.
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
        if (tokenDetails.launched) revert MonadexV1Campaigns__BondingCurveNotActive();

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

    //////////////////////////
    /// Internal Functions ///
    //////////////////////////

    /// @notice Adds the raised liquidity and remainging tokens to Monadex.
    /// @param _token The token address.
    /// @param _tokenDetails The metadata and bonding curve details of the token.
    /// @param _deadline The UNIX timestamp before which the tokens should be added to Monadex.
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

        s_tokenDetails[_token].launched = true;
        ILaunch(_token).launch();
        IOwned(_token).transferOwnership(ZERO_ADDRESS);

        emit BondingCurveCompleted(_token);
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
        return s_minimumVirutalNativeReserve;
    }

    /// @notice Gets the minimum native amount to raise for any newly launched token.
    /// @return The minimum native amount to raise.
    function getMinimumNativeAmountToRaise() external view returns (uint256) {
        return s_minimumNativeAmountToRaise;
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
    function getFee() external view returns (MonadexV1Types.Fraction memory) {
        return s_fee;
    }

    /// @notice Gets the total fee collected by the protocol in native currency.
    /// @return The fee collected by the protocol.
    function getFeeCollected() external view returns (uint256) {
        return s_feeCollected;
    }

    /// @notice Gets the address of the MonadexV1Router.
    /// @return The MonadexV1Router address.
    function getMonadexV1Router() external view returns (address) {
        return i_monadexV1Router;
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
        returns (MonadexV1Types.TokenDetails memory)
    {
        return s_tokenDetails[_token];
    }

    /// @notice Gets the token amount the user will receive and fee to pay in the buy transaction.
    /// @param _token The token address.
    /// @param _nativeAmount The native currency amount to use for buying tokens.
    /// @return The token amount to receive.
    /// @return The fee to be paid in native currency.
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

    /// @notice Gets the wrapped native token amount the user will receive and the fee to pay on the
    /// sell transaction.
    /// @param _token The address of the token.
    /// @param _tokenAmount The amount of tokens to sell.
    /// @return The wrapped native amount to receive.
    /// @return The fee to be paid in native currency.
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
