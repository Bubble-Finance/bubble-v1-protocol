// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IMonadexV1Entropy {
    function getEntropyProvider() external view returns (address);

    function getCurrentSequenceNumber() external view returns (uint64);

    function getCurrentRandomNumber() external view returns (bytes32);
}
