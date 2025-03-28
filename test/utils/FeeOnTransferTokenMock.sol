// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FeeOnTransferToken is ERC20, Ownable {
    uint256 public transferFeeBps; // Fee in basis points (100 = 1%)
    address public feeReceiver;

    event TransferFeeUpdated(uint256 newFeeBps);
    event FeeReceiverUpdated(address newReceiver);

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        uint256 feeBps, // fee in basis points (100 = 0.1%)
        address feeReceiver_
    )
        ERC20(name_, symbol_)
        Ownable(msg.sender)
    {
        require(feeBps <= 1000, "Fee too high"); // Max 10%
        transferFeeBps = feeBps;
        feeReceiver = feeReceiver_;
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }

    function setTransferFee(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 1000, "Fee too high");
        transferFeeBps = newFeeBps;
        emit TransferFeeUpdated(newFeeBps);
    }

    function setFeeReceiver(address newReceiver) external onlyOwner {
        require(newReceiver != address(0), "Invalid receiver");
        feeReceiver = newReceiver;
        emit FeeReceiverUpdated(newReceiver);
    }

    function _update(address from, address to, uint256 value) internal override {
        uint256 feeAmount = (value * transferFeeBps) / 10000;
        uint256 transferAmount = value - feeAmount;

        if (feeAmount > 0) {
            super._update(from, feeReceiver, feeAmount);
        }

        super._update(from, to, transferAmount);
    }
}
