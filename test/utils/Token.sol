// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20, Ownable {
    constructor(
        string memory _name,
        string memory _symbol
    )
        ERC20(_name, _symbol)
        Ownable(msg.sender)
    { }

    function mint(address _account, uint256 _value) external onlyOwner {
        _mint(_account, _value);
    }
}
