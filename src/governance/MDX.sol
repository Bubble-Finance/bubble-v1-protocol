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

import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {
    ERC20Permit,
    Nonces
} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20Votes } from
    "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";

/**
 * @title MDX (Monadex) token.
 * @author Monadex Labs -- Ola hamid.
 * @notice MDX is the governance and utility token of Monadex.
 */
contract MDX is ERC20, ERC20Permit, ERC20Votes, Ownable {
    /**
     * @notice Sets the owner of the token and mints them the initial supply
     * during deployment. The owner will distribute the tokens as per the decided
     * allocation ratios.
     * @param _owner The owner of the token (the protocol team multisig)
     * @param _initialSupply The market cap.
     */
    constructor(
        address _owner,
        uint256 _initialSupply
    )
        ERC20("Monadex", "MDX")
        Ownable(_owner)
        ERC20Permit("Monadex")
    {
        _mint(_owner, _initialSupply);
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
