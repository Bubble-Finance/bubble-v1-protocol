// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// -----------------------------
//    ERC20 Mock Contract
// ----------------------------

contract TestVault {

    error MonadexAddrNotADepositor();
    uint public s_Amount;
    mapping (address depositor => uint amount) public s_Deposit;

    function depositFunds( uint amount ) public {
        s_Deposit[msg.sender] += amount;
    }

    function withDrawFunds (uint amount) public {
        if (s_Deposit[msg.sender] == 0) {
            revert MonadexAddrNotADepositor();
        }
        s_Deposit[msg.sender] -= amount;
    }
}