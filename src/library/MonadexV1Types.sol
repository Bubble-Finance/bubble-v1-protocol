// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title MonadexV1Types.
/// @author Monadex Labs -- mgnfy-view.
/// @notice All type declarations for the protocol collected in one place for convenience.
contract MonadexV1Types {
    /// @notice A fraction struct to store fee percentages, etc.
    struct Fraction {
        /// @dev numerator The fraction numerator.
        uint256 numerator;
        /// @dev denominator The fraction denominator.
        uint256 denominator;
    }

    /// @notice Users leveraging flash swaps and flash loans can execute custom
    /// logic before and after a swap by setting these values.
    struct HookConfig {
        /// @dev hookBeforeCall If true, invoke the before hook on the receiving contract.
        bool hookBeforeCall;
        /// @dev hookAfterCall If true, invoke the after hook on the receiving contract.
        bool hookAfterCall;
    }

    /// @notice Packing parameters for swapping into a struct to avoid stack
    /// too deep errors. To be used by the MonadexV1Pool contract.
    struct SwapParams {
        /// @dev amountAOut The amount of token A to send to the receiver.
        uint256 amountAOut;
        /// @dev amountBOut The amount of token B to send to the receiver.
        uint256 amountBOut;
        /// @dev receiver The address to which the token amounts are directed.
        address receiver;
        /// @dev hookConfig Hook configuration parameters.
        HookConfig hookConfig;
        /// @dev data bytes data to pass to the flash swap or flash loan receiver.
        bytes data;
    }

    /// @notice Packing parameters required for adding liquidity in a struct
    /// to avoid stack too deep errors.
    struct AddLiquidity {
        /// @dev tokenA Address of token A.
        address tokenA;
        /// @dev tokenB Address of token B.
        address tokenB;
        /// @dev amountADesired Maximum amount of token A to add as liquidity.
        uint256 amountADesired;
        /// @dev amountBDesired Maximum amount of token B to add as liquidity.
        uint256 amountBDesired;
        /// @dev amountAMin Minimum amount of token A to add as liquidity.
        uint256 amountAMin;
        /// @dev amountBMin Minimum amount of token B to add as liquidity.
        uint256 amountBMin;
        /// @dev receiver The address to direct the LP tokens to.
        address receiver;
        /// @dev deadline UNIX timestamp (in seconds) before which the liquidity should be added.
        uint256 deadline;
    }

    /// @notice Packing parameters required for adding native cuurency liquidity in a struct
    /// to avoid stack too deep errors.
    struct AddLiquidityNative {
        /// @dev token Address of token.
        address token;
        /// @dev amountTokenDesired Maximum amount of token to add as liquidity.
        uint256 amountTokenDesired;
        /// @dev amountTokenMin Minimum amount of token to add as liquidity.
        uint256 amountTokenMin;
        /// @dev amountNativeMin Minimum amount of native currency to add as liquidity.
        uint256 amountNativeTokenMin;
        /// @dev receiver The address to direct the LP tokens to.
        address receiver;
        /// @dev deadline UNIX timestamp (in seconds) before which the liquidity should be added.
        uint256 deadline;
    }

    /// @notice Allows removal of liquidity from Monadex pools using a permit signature.
    struct RemoveLiquidityWithPermit {
        /// @dev tokenA Address of token A.
        address tokenA;
        /// @dev tokenB Address of token B.
        address tokenB;
        /// @dev lpTokensToBurn Amount of LP tokens to burn.
        uint256 lpTokensToBurn;
        /// @dev amountAMin Minimum amount of token A to withdraw from pool.
        uint256 amountAMin;
        /// @dev amountBMin Minimum amount of token B to withdraw from pool.
        uint256 amountBMin;
        /// @dev receiver The address to direct the withdrawn tokens to.
        address receiver;
        /// @dev deadline The UNIX timestamp (in seconds) before which the liquidity should be removed.
        uint256 deadline;
        /// @dev approveMax Approve maximum amount (type(uint256).max) to the router or just the
        /// required LP token amount.
        bool approveMax;
        /// @dev v The v part of the signature.
        uint8 v;
        /// @dev r The r part of the signature.
        bytes32 r;
        /// @dev s The s part of the signature.
        bytes32 s;
    }

    /// @notice Allows removal of native currency liquidity from Monadex pools using a permit.
    struct RemoveLiquidityNativeWithPermit {
        /// @dev token Address of token.
        address token;
        /// @dev lpTokensToBurn Amount of LP tokens to burn.
        uint256 lpTokensToBurn;
        /// @dev amountTokenMin Minimum amount of token to withdraw from pool.
        uint256 amountTokenMin;
        /// @dev amountNativeMin Minimum amount of native currency to withdraw from pool.
        uint256 amountNativeMin;
        /// @dev receiver The address to direct the withdrawn tokens to.
        address receiver;
        /// @dev deadline The UNIX timestamp (in seconds) before which the liquidity should be removed.
        uint256 deadline;
        /// @dev approveMax Approve maximum amount (type(uint256).max) to the router or just
        /// the required LP token amount.
        bool approveMax;
        /// @dev v The v part of the signature.
        uint8 v;
        /// @dev r The r part of the signature.
        bytes32 r;
        /// @dev s The s part of the signature.
        bytes32 s;
    }

    /// @notice Purchase tickets with a multiplier value during a swap.
    struct PurchaseTickets {
        /// @dev purchaseTickets True, if the user wants to pruchase tickets, false otherwise.
        bool purchaseTickets;
        /// @dev multiplier The multiplier to apply to the ticket purchase. The higher the multiplier,
        /// the higher fees is taken, and more raffle tickets are obtained.
        Multipliers multiplier;
        /// @dev minimumTicketsToReceive Slippage protection for ticket purchase.
        uint256 minimumTicketsToReceive;
    }

    /// @notice The Pyth price feed config for the raffle contract.
    struct PriceFeedConfig {
        /// @dev priceFeedId The token/usd price feed id.
        bytes32 priceFeedId;
        /// @dev noOlderThan The max age before a price feed can be considered stale.
        uint256 noOlderThan;
    }

    /// @notice Multipliers can be selected for raffle ticket purchase. Each multiplier is
    /// associated with a percentage.
    enum Multipliers {
        Multiplier1,
        Multiplier2,
        Multiplier3
    }

    /// @notice Details of a token launched on MonadexV1Campaigns.
    struct TokenDetails {
        /// @dev name The token name.
        string name;
        /// @dev symbol The token ticker.
        string symbol;
        /// @dev creator The address of the creator of the token.
        address creator;
        /// @dev tokenReserve Tracks the amount of tokens held by the bonding curve.
        uint256 tokenReserve;
        /// @dev nativeReserve Tracks the amount of native currency held by the bonding curve plus
        /// the initial virtual amount.
        uint256 nativeReserve;
        /// @dev virtualNativeReserve The initial virtual native currency amount used to set the initial
        /// price of a token.
        uint256 virtualNativeReserve;
        /// @dev targetNativeReserve The target native currency amount to reach before listing the token
        /// on Monadex. This includes the initial virtual native currency amount.
        uint256 targetNativeReserve;
        /// @dev tokenCreatorReward The reward (in native wrapped token) to be given to the token creator
        /// once the token is successfully listed on Monadex.
        uint256 tokenCreatorReward;
        /// @dev liquidityMigrationFee The fee taken by the protcol on each successful listing (in native
        /// currency).
        uint256 liquidityMigrationFee;
        /// @dev Tells if the token has completed its bonding curve or not.
        bool launched;
    }
}
