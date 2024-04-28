// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract MonadexV1AuxiliaryTypes {
    struct AddLiquidity {
        address tokenA;
        address tokenB;
        uint256 amountADesired;
        uint256 amountBDesired;
        uint256 amountAMin;
        uint256 amountBMin;
        address receiver;
        uint256 deadline;
        PurchaseTickets purchaseTickets;
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
