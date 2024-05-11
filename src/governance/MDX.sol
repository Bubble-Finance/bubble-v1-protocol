// Layout:
//     - pragma
//     - imports
//     - interfaces, libraries, contracts
//     - type declarations
//     - state variables
//     - events
//     - errors
//     - modifiers
//     - functions
//         - constructor
//         - receive function (if exists)
//         - fallback function (if exists)
//         - external
//         - public
//         - internal
//         - private
//         - view and pure functions

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Permit, Nonces} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";


/// @title MDX(Monadex) Token  
/// @author Ola hamid
/// @notice MDX is the native token of Monadex, with minting, burning, and voting capabilities.

contract MDX is ERC20, Ownable, ERC20Permit, ERC20Votes {
    constructor(address initialOwner)
        ERC20("Monadex", "MDX")
        Ownable(initialOwner)
        ERC20Permit("Monadex")
    {}


    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn (address to, uint256 amount) public onlyOwner {
        _burn(to, amount);
    }

    // The functions below are overrides required by Solidity using openZepplin.
    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address ownerOfNonce)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(ownerOfNonce);
    }


}

