// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title MonadexV1Types.
 * @author Monadex Labs -- mgnfy-view.
 * @notice Type declarations for the protocol.
 */
contract MonadexV1Types {
    /**
     * @notice The fee is always a percentage of the amount in consideration.
     * @param numerator The fee numerator.
     * @param denominator The fee denominator.
     */
    struct Fee {
        uint256 numerator;
        uint256 denominator;
    }

    /**
     * @notice Users leveraging flash swaps and flash loans can execute custom
     * logic before and after a swap by setting these values.
     * @param hookBeforeCall If true, invoke the before hook on the receiving contract.
     * @param hookAfterCall If true, invoke the after hook on the receiving contract.
     */
    struct HookConfig {
        bool hookBeforeCall;
        bool hookAfterCall;
    }

    /**
     * @notice Packing parameters for swapping into a struct to avoid stack
     * too deep errors.
     * @param amountAOut The amount of token A to send to the receiver.
     * @param amountBOut The amount of token B to send to the receiver.
     * @param receiver The address to which the token amounts are directed.
     * @param hookConfig Hook configuration parameters.
     * @param data bytes data to pass to the flash swap or flash loan receiver.
     */
    struct SwapParams {
        uint256 amountAOut;
        uint256 amountBOut;
        address receiver;
        HookConfig hookConfig;
        bytes data;
    }

    /**
     * @notice Packing parameters required for adding liquidity in a struct
     * to avoid stack too deep errors.
     * @param tokenA Address of token A.
     * @param tokenB Address of token B.
     * @param amountADesired Maximum amount of token A to add as liquidity.
     * @param amountBDesired Maximum amount of token B to add as liquidity.
     * @param amountAMin Minimum amount of token A to add as liquidity.
     * @param amountBMin Minimum amount of token B to add as liquidity.
     * @param receiver The address to direct the LP tokens to.
     * @param deadline UNIX timestamp before which the liquidity should be added.
     */
    struct AddLiquidity {
        address tokenA;
        address tokenB;
        uint256 amountADesired;
        uint256 amountBDesired;
        uint256 amountAMin;
        uint256 amountBMin;
        address receiver;
        uint256 deadline;
    }

    /**
     * @notice Packing parameters required for adding native token liquidity in a struct
     * to avoid stack too deep errors.
     * @param token Address of token.
     * @param amountTokenDesired Maximum amount of token to add as liquidity.
     * @param amountTokenMin Minimum amount of token to add as liquidity.
     * @param amountNativeMin Minimum amount of native currency to add as liquidity.
     * @param receiver The address to direct the LP tokens to.
     * @param deadline UNIX timestamp before which the liquidity should be added.
     */
    struct AddLiquidityNative {
        address token;
        uint256 amountTokenDesired;
        uint256 amountTokenMin;
        uint256 amountNativeTokenMin;
        address receiver;
        uint256 deadline;
    }

    /**
     * @notice Allows removal of liquidity from Monadex pools using a permit.
     * @param tokenA Address of token A.
     * @param tokenB Address of token B.
     * @param lpTokensToBurn Amount of LP tokens to burn.
     * @param amountAMin Minimum amount of token A to withdraw from pool.
     * @param amountBMin Minimum amount of token B to withdraw from pool.
     * @param receiver The address to direct the withdrawn tokens to.
     * @param deadline The UNIX timestamp before which the liquidity should be removed.
     * @param approveMax Approve maximum amount (type(uint256).max) to the router or just the
     * required LP token amount.
     * @param v The v part of the signature.
     * @param r The r part of the signature.
     * @param s The s part of the signature.
     */
    struct RemoveLiquidityWithPermit {
        address tokenA;
        address tokenB;
        uint256 lpTokensToBurn;
        uint256 amountAMin;
        uint256 amountBMin;
        address receiver;
        uint256 deadline;
        bool approveMax;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /**
     * @notice Allows removal of native currency liquidity from Monadex pools using a permit.
     * @param token Address of token.
     * @param lpTokensToBurn Amount of LP tokens to burn.
     * @param amountTokenMin Minimum amount of token to withdraw from pool.
     * @param amountNativeMin Minimum amount of native currency to withdraw from pool.
     * @param receiver The address to direct the withdrawn tokens to.
     * @param deadline The UNIX timestamp before which the liquidity should be removed.
     * @param approveMax Approve maximum amount (type(uint256).max) to the router or just
     * the required LP token amount.
     * @param v The v part of the signature.
     * @param r The r part of the signature.
     * @param s The s part of the signature.
     */
    struct RemoveLiquidityNativeWithPermit {
        address token;
        uint256 lpTokensToBurn;
        uint256 amountTokenMin;
        uint256 amountNativeMin;
        address receiver;
        uint256 deadline;
        bool approveMax;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /**
     * @notice Purchase tickets with a multiplier value during a swap.
     * @param purchaseTickets True, if the user wants to pruchase tickets, false otherwise.
     * @param multiplier The multiplier to apply to the ticket purchase. The higher the multiplier,
     * the higher fees is taken, and more raffle tickets are obtained.
     * @param minimumTicketsToReceive Slippage protection for ticket purchase.
     */
    struct PurchaseTickets {
        bool purchaseTickets;
        Multipliers multiplier;
        uint256 minimumTicketsToReceive;
    }

    /**
     * @notice The price feed config for the raffle contract.
     * @param priceFeedId The token/usd price feed id.
     * @param noOlderThan The max age before a price feed can be considered stale.
     */
    struct PriceFeedConfig {
        bytes32 priceFeedId;
        uint256 noOlderThan;
    }

    /**
     * @notice A multiplier is associated with a percentage.
     * @param Multiplier1 A small percentage of swap amount is used to purchase tickets.
     * @param Multiplier2 A slightly higher percentage of swap amount is used to purchase tickets.
     * @param Multiplier3 A higher percentage of swap amount is used to purchase tickets.
     */
    enum Multipliers {
        Multiplier1,
        Multiplier2,
        Multiplier3
    }
}
