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

/**
 * @title MonadexV1PythRandomNumberGenerator.
 * @author Monadex Labs -- Ola Hamid.
 * @notice .
 */

 abstract contract pythContract is IEntropyConsumer {
    error pyth_notEnoughFee();

    IEntropy internal entropy;
    address private EntropyProvider;
    //using pyth entropy you need to store bith the entropy and Enthropy provider to be used for requests
    //provider commit to a sequence of random No

    constructor(address _entropy, address _EntropyProvider) {
        entropy = IEntropy(_entropy);
        EntropyProvider = _EntropyProvider;
    }

    function revealRandomNumber(uint generatedRandomNumber) external returns(bytes32){
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
    /// param for the commintment we can either choose to generate the commitment off chain or onchain. the onchain way is what im using right now
    function requestSequenceNumber(/*bytes32 commitment*/) public payable returns (uint64) {
        bytes32 commitment = getCommitment();
        //fee is required to be paid in native gass token that is used to byy the calling contract.
        uint256 fee = getFee();
        //since we are calling the fee by a contract and not an address we have to set a gas limit or gass price so there wont run out of gas or over spend ether
        if (fee > msg.value) {
            revert pyth_notEnoughFee();
        }
        //request randomNumber from the from the entropy contract the call request a sequence number from pyth oracle that is uniquely identified to generate the final random number
        uint64 sequenceNumber = entropy.request{value: fee}(EntropyProvider, commitment, true);
        return sequenceNumber;
    }

    /////////////////////
    ///getter function///
    /////////////////////
    function getFee() public view returns (uint256 fee) {
      fee = entropy.getFee(EntropyProvider);
  }


    // Simulate a random number generation by using the blockhash 
    function getRandomNumber() public view returns (bytes32) {
        uint256 randomNumber = uint256(blockhash(block.number - 1));
        return bytes32(randomNumber);
    }

    function getCommitment() public view returns (bytes32) {
      bytes32 commitment = getRandomNumber();
      return keccak256(abi.encodePacked(commitment));
    }
    
    function getEntropy() internal view override returns (address) {
      return address(entropy);
  }
  /// 
  /// @param generatedNumber can be gotten from https://fortuna-staging.dourolabs.app from the TS side 

  function getProviderRandomNumber(uint generatedNumber) public pure returns (bytes32) {
   bytes32 generatedBytesNumber =  bytes32(generatedNumber);
    return generatedBytesNumber;
  }
}