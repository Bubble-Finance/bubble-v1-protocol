// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// -----------------------------
//    ERC20 Mock Contract
// ----------------------------

contract TestVault {
    error BubbleAddrNotADepositor();

    uint256 public s_Amount;
    mapping(address depositor => uint256 amount) public s_Deposit;

    function depositFunds(uint256 amount) public {
        s_Deposit[msg.sender] += amount;
    }

    function withDrawFunds(uint256 amount) public {
        if (s_Deposit[msg.sender] == 0) {
            revert BubbleAddrNotADepositor();
        }
        s_Deposit[msg.sender] -= amount;
    }
}
