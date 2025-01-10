// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title MonadexV1Types.
/// @author Monadex Labs -- mgnfy-view.
/// @notice All type declarations for the protocol are collected here for convenience.
contract MonadexV1Types {
    /// @notice A fraction struct to store fee percentages, etc.
    struct Fraction {
        /// @dev The fraction numerator.
        uint256 numerator;
        /// @dev The fraction denominator.
        uint256 denominator;
    }

    /// @notice Users leveraging flash swaps and flash loans can execute custom
    /// logic before and after a swap by setting these values.
    struct HookConfig {
        /// @dev If true, invoke the `before swap hook` on the receiving contract.
        bool hookBeforeCall;
        /// @dev If true, invoke the `after swap hook` on the receiving contract.
        bool hookAfterCall;
    }

    /// @notice Packing parameters for swapping into a struct to avoid stack
    /// too deep errors. To be used by the `MonadexV1Pool` contract.
    struct SwapParams {
        /// @dev The amount of token A to send to the receiver.
        uint256 amountAOut;
        /// @dev The amount of token B to send to the receiver.
        uint256 amountBOut;
        /// @dev The address to which the token amounts are directed.
        address receiver;
        /// @dev Hook configuration parameters.
        HookConfig hookConfig;
        /// @dev Bytes data to pass to the flash swap or flash loan receiver.
        bytes data;
    }

    /// @notice Packing parameters required for adding liquidity in a struct
    /// to avoid stack too deep errors.
    struct AddLiquidity {
        /// @dev Address of token A.
        address tokenA;
        /// @dev Address of token B.
        address tokenB;
        /// @dev Maximum amount of token A to add as liquidity.
        uint256 amountADesired;
        /// @dev Maximum amount of token B to add as liquidity.
        uint256 amountBDesired;
        /// @dev Minimum amount of token A to add as liquidity.
        uint256 amountAMin;
        /// @dev Minimum amount of token B to add as liquidity.
        uint256 amountBMin;
        /// @dev The address to direct the LP tokens to.
        address receiver;
        /// @dev UNIX timestamp (in seconds) before which the liquidity should be added.
        uint256 deadline;
    }

    /// @notice Packing parameters required for adding native token liquidity in a struct
    /// to avoid stack too deep errors.
    struct AddLiquidityNative {
        /// @dev Address of token.
        address token;
        /// @dev Maximum amount of token to add as liquidity.
        uint256 amountTokenDesired;
        /// @dev Minimum amount of token to add as liquidity.
        uint256 amountTokenMin;
        /// @dev Minimum amount of native token to add as liquidity.
        uint256 amountNativeTokenMin;
        /// @dev The address to direct the LP tokens to.
        address receiver;
        /// @dev UNIX timestamp (in seconds) before which the liquidity should be added.
        uint256 deadline;
    }

    /// @notice Allows removal of liquidity from Monadex pools using a permit signature.
    struct RemoveLiquidityWithPermit {
        /// @dev Address of token A.
        address tokenA;
        /// @dev Address of token B.
        address tokenB;
        /// @dev Amount of LP tokens to burn.
        uint256 lpTokensToBurn;
        /// @dev Minimum amount of token A to withdraw from pool.
        uint256 amountAMin;
        /// @dev Minimum amount of token B to withdraw from pool.
        uint256 amountBMin;
        /// @dev The address to direct the withdrawn tokens to.
        address receiver;
        /// @dev The UNIX timestamp (in seconds) before which the liquidity should be removed.
        uint256 deadline;
        /// @dev Approve maximum amount (type(uint256).max) to the router or just the
        /// required LP token amount.
        bool approveMax;
        /// @dev The v part of the signature.
        uint8 v;
        /// @dev The r part of the signature.
        bytes32 r;
        /// @dev The s part of the signature.
        bytes32 s;
    }

    /// @notice Allows removal of native currency liquidity from Monadex pools using a permit.
    /// Packing parameters in a struct to avoid stack too deep errors.
    struct RemoveLiquidityNativeWithPermit {
        /// @dev Address of token.
        address token;
        /// @dev Amount of LP tokens to burn.
        uint256 lpTokensToBurn;
        /// @dev Minimum amount of token to withdraw from pool.
        uint256 amountTokenMin;
        /// @dev Minimum amount of native currency to withdraw from pool.
        uint256 amountNativeMin;
        /// @dev The address to direct the withdrawn tokens to.
        address receiver;
        /// @dev The UNIX timestamp (in seconds) before which the liquidity should be removed.
        uint256 deadline;
        /// @dev Approve maximum amount (type(uint256).max) to the router or just
        /// the required LP token amount.
        bool approveMax;
        /// @dev The v part of the signature.
        uint8 v;
        /// @dev The r part of the signature.
        bytes32 r;
        /// @dev The s part of the signature.
        bytes32 s;
    }

    /// @notice The Pyth price feed config for raffle.
    struct PriceFeedConfig {
        /// @dev The token/usd price feed id.
        bytes32 priceFeedId;
        /// @dev The max window after which the price feed will be considered stale.
        uint256 noOlderThan;
    }

    /// @notice Enter raffle during a swap on supported pools.
    struct Raffle {
        /// @dev True if the user wants to enter raffle, false otherwise.
        bool enter;
        /// @dev The fraction of swap amount that should be used to enter raffle.
        Fraction fractionOfSwapAmount;
        /// @dev The receiver of the raffle nft.
        address raffleNftReceiver;
    }

    /// @notice Raffle winning tiers.
    enum Tiers {
        TIER1,
        TIER2,
        TIER3
    }

    /// @notice Raffle winnings claim struct to avoid stack too deep error.
    struct RaffleClaim {
        /// @dev The tier to claim winnings in.
        Tiers tier;
        /// @dev The epoch to claim winnings from.
        uint256 epoch;
        /// @dev The raffle Nft tokenId to claim winnings on behalf of.
        uint256 tokenId;
    }

    /// @notice Details of a token launched on `MonadexV1Campaigns`.
    struct TokenDetails {
        /// @dev The token name.
        string name;
        /// @dev The token ticker.
        string symbol;
        /// @dev The address of the creator of the token.
        address creator;
        /// @dev Tracks the amount of tokens held by the bonding curve.
        uint256 tokenReserve;
        /// @dev Tracks the amount of native token held by the bonding curve plus
        /// the initial virtual amount.
        uint256 nativeTokenReserve;
        /// @dev The initial virtual native token amount used to set the initial
        /// price of a token.
        uint256 virtualNativeTokenReserve;
        /// @dev The target native token amount to reach before listing the token
        /// on Monadex. This includes the initial virtual native token amount.
        uint256 targetNativeTokenReserve;
        /// @dev The reward (in native wrapped token) to be given to the token creator
        /// once the token is successfully listed on Monadex.
        uint256 tokenCreatorReward;
        /// @dev The fee taken by the protcol on each successful listing (in native
        /// currency).
        uint256 liquidityMigrationFee;
        /// @dev Tells if the token has completed its bonding curve or not.
        bool launched;
    }
}
