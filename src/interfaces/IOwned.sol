// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IOwned {
    function transferOwnership(address _newOwner) external;
}
