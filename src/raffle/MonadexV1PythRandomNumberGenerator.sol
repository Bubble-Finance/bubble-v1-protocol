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

import { IEntropyConsumer } from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import { IEntropy } from "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";

/**
 * @title MonadexV1PythRandomNumberGenerator.
 * @author Monadex Labs -- Ola Hamid.
 * @notice pythRandomNumberGenerator allow the raffle contract to call the reveal function and generate a random number.
 */

 contract MonadexV1PythRandomNumber {
    error pyth_notEnoughFee();
    
    // using pyth entropy you need to store both the entropy and Enthropy provider to be used for requests
    IEntropy internal entropy;
    address private EntropyProvider;


    constructor(
      address _entropy, 
      address _EntropyProvider) 
      {
        entropy = IEntropy(_entropy);
        EntropyProvider = _EntropyProvider;
    }
    /**
     * 
     * @param generatedRandomNumber can be gotten from https://fortuna-staging.dourolabs.app from the TS/web.js side 
     * @notice convert the bytes value from revealRandomByte32 to a uint
     */
    function revealRandomNumber(uint generatedRandomNumber) external returns(uint){
      bytes32 revealRandomBytes32 = revealRandomByte32(generatedRandomNumber);

      uint _revealRandomNumber = uint(revealRandomBytes32);
      // Return the converted value
      return _revealRandomNumber;
    }

    /** 
     * @dev revealRandomByte reveals random bytes32
     * @notice the generated random bytes Invoke the reveal method on the IEntropy contract, This method will combine the user and provider's random numbers, along with the blockhash, to construct the final secure random number.
     */
    function revealRandomByte32(uint generatedRandomNumber) internal returns(bytes32){
      uint64 sequenceNumber = requestSequenceNumber();
      bytes32 randomNumber = getRandomNumber();
      bytes32 providerRandomNumber = getProviderRandomNumber(generatedRandomNumber);
      bytes32 revealByteNumber = entropy.reveal(
        EntropyProvider,
        sequenceNumber,
        randomNumber,
        providerRandomNumber
      );
      return revealByteNumber;

    }

    /**
     * @dev the function requestSequenceNumber 
     * @notice this function request randomNumber from the entropy contract the call request a sequence number from pyth oracle that is uniquely identified to generate the final random number 
     * param for commintment that is currently being commented out, we(monadex_lab) can either choose to generate the commitment off chain or onchain. the onchain way is being used right now
     * fee is required to be paid in native gass token that is used to byy the calling contract.since we are calling the fee by a contract and not an address we have to set a gas limit or gass price so there wont run out of gas or over spend ether.
     */
    function requestSequenceNumber(/*bytes32 commitment*/) public payable returns (uint64) {
        bytes32 commitment = getCommitment();
        uint256 fee = getFee();
        if (fee > msg.value) {
            revert pyth_notEnoughFee();
        }

        uint64 sequenceNumber = entropy.request{value: fee}(EntropyProvider, commitment, true);
        return sequenceNumber;
    }

    /////////////////////
    ///getter function///
    /////////////////////

    function getFee() public view returns (uint256 fee) {
      fee = entropy.getFee(EntropyProvider);
  }


    /**
     * @dev the getRandomNumber Simulate a random number generation by using the blockhash. note that this can also be generated offchain using web3.js
     */ 
    function getRandomNumber() public view returns (bytes32) {
        uint256 randomNumber = uint256(blockhash(block.number - 1));
        return bytes32(randomNumber);
    }
    /**
     * @dev getCommitment
     * @return the concatinated blochhash, from the getRandomNumber function
     */
    function getCommitment() public view returns (bytes32) {
      bytes32 commitment = getRandomNumber();
      return keccak256(abi.encodePacked(commitment));
    }
    /**
     * @dev getEntropy
     * @return the entropy address
     */
    function getEntropy() internal view returns (address) {
      return address(entropy);
  }
  
  /// @param generatedNumber can be gotten from https://fortuna-staging.dourolabs.app from the TS side 
  function getProviderRandomNumber(uint generatedNumber) public pure returns (bytes32) {
   bytes32 generatedBytesNumber =  bytes32(generatedNumber);
    return generatedBytesNumber;
  }
}