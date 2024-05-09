// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract MonadexV1AuxiliaryTypes {
    /**
     * @notice The parameters required for adding liquidity were packed in a struct
     * to avoid stack too deep errors.
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

    struct PurchaseTickets {
        bool purchaseTickets;
        Multipliers multiplier;
    }

    enum Multipliers {
        Multiplier1,
        Multiplier2,
        Multiplier3
    }
}
