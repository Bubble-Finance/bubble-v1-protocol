// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@pythnetwork/entropy-sdk-solidity/EntropyStructs.sol";
import "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";

contract MockEntropy is IEntropy {
    uint64 public sequenceNumber;
    bytes32 public randomNumber;

    constructor(bytes32 _randomNumber) {
        randomNumber = _randomNumber;
    }

    function getFee(address) external pure override returns (uint128) {
        return 0;
    }

    function requestWithCallback(
        address provider,
        bytes32 userRandomNumber
    )
        external
        payable
        override
        returns (uint64)
    {
        sequenceNumber++;
        IEntropyConsumer(msg.sender)._entropyCallback(sequenceNumber, provider, randomNumber);
        return sequenceNumber;
    }

    function combineRandomValues(
        bytes32 userRandomness,
        bytes32 providerRandomness,
        bytes32 blockHash
    )
        external
        pure
        override
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(userRandomness, providerRandomness, blockHash));
    }

    function getProviderInfo(address)
        external
        pure
        override
        returns (EntropyStructs.ProviderInfo memory)
    {
        return EntropyStructs.ProviderInfo({
            feeInWei: 0,
            accruedFeesInWei: 0,
            originalCommitment: bytes32(0),
            originalCommitmentSequenceNumber: uint64(0),
            commitmentMetadata: "",
            uri: bytes(""),
            endSequenceNumber: uint64(0),
            sequenceNumber: uint64(1),
            currentCommitment: bytes32(0),
            currentCommitmentSequenceNumber: uint64(0),
            feeManager: address(0)
        });
    }

    function getRequest(
        address provider,
        uint64 _sequenceNumber
    )
        external
        pure
        override
        returns (EntropyStructs.Request memory)
    {
        return EntropyStructs.Request({
            provider: address(0),
            sequenceNumber: 0,
            numHashes: uint32(0),
            commitment: bytes32(0),
            blockNumber: 10,
            requester: address(0),
            useBlockhash: false,
            isRequestWithCallback: true
        });
    }

    function reveal(address, uint64, bytes32, bytes32) external pure override returns (bytes32) {
        return bytes32(0);
    }

    function revealWithCallback(address, uint64, bytes32, bytes32) external pure override { }

    function setFeeManager(address) external pure override { }

    function setProviderFee(uint128) external pure override { }

    function setProviderFeeAsFeeManager(address, uint128) external pure override { }

    function setProviderUri(bytes calldata) external pure override { }

    function withdraw(uint128) external pure override { }

    function withdrawAsFeeManager(address, uint128) external pure override { }

    function setRandomNumber(bytes32 _randomNumber) external {
        randomNumber = _randomNumber;
    }

    function constructUserCommitment(bytes32 userRandomness)
        external
        pure
        override
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(userRandomness));
    }

    function getAccruedPythFees() external pure override returns (uint128) {
        return 0;
    }

    function getDefaultProvider() external view override returns (address provider) {
        return address(this);
    }

    function register(
        uint128 feeInWei,
        bytes32 commitment,
        bytes calldata commitmentMetadata,
        uint64 chainLength,
        bytes calldata uri
    )
        external
        pure
        override
    { }

    function request(address, bytes32, bool) external payable override returns (uint64) {
        return 0;
    }
}
