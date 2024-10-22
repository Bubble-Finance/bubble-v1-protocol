// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";

contract InitializeEntropy is IEntropyConsumer {
    IEntropy entropy;
    address provider;
    uint256 raffleRandomNumber;

    constructor(address _entropy, address _provider) {
        entropy = IEntropy(_entropy);
        provider = _provider;
    }

    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }

    /* @audit-note: 
     ******** <ether.js> const userRandomNumber = ethers.utils.randomBytes(32);
     ******** <web3.js>  const userRandomNumber = web3.utils.randomHex(32);
     */
    function request(bytes32 userRandomNumber) external payable {
        // Fees = 0 in the MockEnthropy
        uint128 requestFee = entropy.getFee(provider);
        if (msg.value < requestFee) revert("not enough fees");

        uint64 sequenceNumber =
            entropy.requestWithCallback{ value: requestFee }(provider, userRandomNumber);
    }

    function entropyCallback(
        uint64 sequenceNumber,
        address _providerAddress,
        bytes32 _randomNumber
    )
        internal
        override
    {
        bytes32 randomNumber = _randomNumber;
        raffleRandomNumber = uint256(randomNumber);
    }

    function getRandomNumber() public view returns (uint256) {
        return raffleRandomNumber;
    }

    receive() external payable { }
}
