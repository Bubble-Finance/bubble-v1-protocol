// SPDX-License-Identifier: MIT
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

/// @title MonadexV1Raffle
/// @author Ola Hamid
/// @notice ....
/// @notice

pragma solidity ^0.8.20;

import { Ownable } from "../../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract MonadexTicket is Ownable, ERC20 {
    error MTicket_untransferable();

    constructor() Ownable(msg.sender) ERC20("MonadexTicket", "MDXT") { }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        _burn(from, amount);
    }

    /**
     * @dev non transferable ticket tokens to not allow users send transfer out tickets
     */
    function transferFrom(
        address, /*from*/
        address, /*to*/
        uint256 /*value*/
    )
        public
        pure
        override
        returns (bool)
    {
        revert MTicket_untransferable();
    }

    function transfer(
        address, /*recipient*/
        uint256 /*amount*/
    )
        public
        pure
        override
        returns (bool)
    {
        revert MTicket_untransferable();
    }
}
