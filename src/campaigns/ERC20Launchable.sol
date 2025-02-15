// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { Owned } from "@solmate/auth/Owned.sol";

/// @title ERC20Launchable.
/// @author Monadex labs -- mgnfy-view.
/// @notice An ERC20 token which is not tradeable before launch (only transfers from/to owner
/// are supported). This is to prevent tokens that have not completed their bonding curve
/// from being listed on other dexes, lending protocols, etc. Once the token completes its bonding
/// curve and has been listed on Monadex, the restriction is removed. Ownership of this token
/// by MonadexV1Campaigns is renounced.
contract ERC20Launchable is ERC20, Owned {
    ///////////////////////
    /// State Variables ///
    ///////////////////////

    /// @dev Tells if the token has been listed on Monadex or not, and that if it can be
    /// traded freely.
    bool private s_launched;

    //////////////
    /// Events ///
    //////////////

    event Launched();

    //////////////
    /// Errors ///
    //////////////

    error ERC20Launchable__NotLaunchedYet();

    ///////////////////
    /// Constructor ///
    ///////////////////

    /// @notice Initialized the token's metadata, and mints the total supply to MonadexV1Campaigns.
    /// @param _name The name of the token.
    /// @param _symbol The symbol of the token.
    /// @param _totalSupply The total supply of the token.
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply
    )
        ERC20(_name, _symbol)
        Owned(msg.sender)
    {
        _mint(msg.sender, _totalSupply);
    }

    //////////////////////////
    /// External Functions ///
    //////////////////////////

    /// @notice Allows the owner (MonadexV1Campaigns) to launch the token after it has successfully
    /// completed it's bonding curve on MonadexV1Campaigns.
    function launch() external onlyOwner {
        s_launched = true;

        emit Launched();
    }

    //////////////////////////
    /// Internal Functions ///
    //////////////////////////

    /// @notice If the token hasn't completed it's bonding curve, restrict transfers such that
    /// tokens can only be transferred to/from owner. If the token has been successfully
    /// launched, remove restrictions.
    /// @param _from Sender of the token.
    /// @param _to Recipient of the token.
    /// @param _value The amount of tokens to transfer.
    function _update(address _from, address _to, uint256 _value) internal override {
        if (!s_launched) {
            if (_from != owner && _to != owner) revert ERC20Launchable__NotLaunchedYet();
        }
        super._update(_from, _to, _value);
    }

    ///////////////////////////////
    /// View and Pure Functions ///
    ///////////////////////////////

    /// @notice Tells if the token has successfully completed it's bonding curve or not, and that
    /// if it's freely tradeable or not.
    /// @return The lanch state of the token.
    function isLaunched() external view returns (bool) {
        return s_launched;
    }
}
