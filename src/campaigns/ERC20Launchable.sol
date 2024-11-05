// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { Owned } from "@solmate/auth/Owned.sol";

contract ERC20Launchable is ERC20, Owned {
    bool private s_launched;

    error ERC20Launchable__NotLaunchedYet();

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

    function _update(address _from, address _to, uint256 _value) internal override {
        if (!s_launched) {
            if (_from != owner || _to != owner) revert ERC20Launchable__NotLaunchedYet();
        }
        super._update(_from, _to, _value);
    }

    function launch() external onlyOwner {
        s_launched = true;
    }

    function isLaunched() external view returns (bool) {
        return s_launched;
    }
}
