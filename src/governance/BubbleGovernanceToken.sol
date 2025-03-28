// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit, Nonces } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

/// @title Bubble token.
/// @author Bubble Finance -- Ola hamid.
/// @notice Bubble is the governance and utility token of Bubble protocol.
contract BubbleGovernanceToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    ///////////////////
    /// Constructor ///
    ///////////////////

    /// @notice Sets the owner of the token and mints them the initial supply
    /// during deployment. The owner will distribute the tokens as per the decided
    /// allocation ratios later on.
    /// @param _owner The owner of the token (the protocol team multisig).
    /// @param _initialSupply The market cap.
    constructor(
        address _owner,
        uint256 _initialSupply
    )
        ERC20("Bubble", "BUBBLE")
        Ownable(_owner)
        ERC20Permit("Bubble")
    {
        _mint(_owner, _initialSupply);
    }

    // The functions below are overrides required by Solidity using openZepplin.

    //////////////////////////
    /// Internal Functions ///
    //////////////////////////

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

    ///////////////////////////////
    /// View and Pure Functions ///
    ///////////////////////////////

    function nonces(
        address ownerOfNonce
    )
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(ownerOfNonce);
    }
}
