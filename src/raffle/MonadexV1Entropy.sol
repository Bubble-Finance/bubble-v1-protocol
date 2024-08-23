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
pragma solidity 0.8.24;

import { IEntropy } from "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import { IEntropyConsumer } from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";

import { IMonadexV1Entropy } from "../interfaces/IMonadexV1Entropy.sol";

/**
 * @title MonadexV1Entropy.
 * @author Monadex Labs -- mgnfy-view.
 * @notice This contract stores state associated with getting a random number,
 * and the entropy callback function.
 */
abstract contract MonadexV1Entropy is IEntropyConsumer, IMonadexV1Entropy {
    ///////////////////////
    /// State Variables ///
    ///////////////////////

    /**
     * @dev The Pyth contract which we'll use to request random numbers from.
     */
    address internal immutable i_entropy;
    /**
     * @dev We can use different entropy providers to request random numbers
     * from.
     */
    address internal immutable i_entropyProvider;
    /**
     * @dev This is the sequence number for which Pyth will supply a random number
     * for a given week's draw.
     * After each draw, the sequence number is set to 0 for the next week.
     */
    uint64 internal s_currentSequenceNumber;
    /**
     * @dev This is the random number supplied by Pyth for the current sequence
     * number.
     * After each draw, the random number is set to bytes32(0) for the next week.
     */
    bytes32 internal s_currentRandomNumber;

    //////////////
    /// Events ///
    //////////////

    event RandomNumberSupplied(
        uint64 indexed currentSequenceNumber, bytes32 indexed currentRandomNumber
    );

    //////////////
    /// Errors ///
    //////////////

    error MonadexV1Raffle__SequenceNumbersDoNotMatch(
        uint64 suppliedSequenceNumber, uint64 currentSequenceNumber
    );
    error MonadexV1Raffle__RandomNumberAlreadySupplied(bytes32 randomNumber);

    ///////////////////
    /// Constructor ///
    ///////////////////

    /**
     * @notice Initializes the entropy contract address and the entropy provider.
     * @param _entropyContract The address of the Pyth entropy contract.
     * @param _entropyProvider The entropy provider's address.
     */
    constructor(address _entropyContract, address _entropyProvider) {
        i_entropy = _entropyContract;
        i_entropyProvider = _entropyProvider;
    }

    /**
     * @notice Once a random number is received, this function is called by Pyth and the
     * random number is stored for drawing winners in a separate transaction.
     * @param _sequenceNumber The number associated with each request.
     * @param _randomNumber The supplied random number for the sequence number.
     */
    function entropyCallback(
        uint64 _sequenceNumber,
        address,
        bytes32 _randomNumber
    )
        internal
        override
    {
        if (_sequenceNumber != s_currentSequenceNumber) {
            revert MonadexV1Raffle__SequenceNumbersDoNotMatch(
                _sequenceNumber, s_currentSequenceNumber
            );
        }
        if (s_currentRandomNumber != bytes32(0)) {
            revert MonadexV1Raffle__RandomNumberAlreadySupplied(s_currentRandomNumber);
        }

        s_currentRandomNumber = _randomNumber;

        emit RandomNumberSupplied(_sequenceNumber, _randomNumber);
    }

    //////////////////////////////
    /// View and Pure Function ///
    //////////////////////////////

    /**
     * @notice Gets the address of the Pyth entropy contract.
     * @return The entropy contract's address.
     */
    function getEntropy() internal view override returns (address) {
        return i_entropy;
    }

    /**
     * @notice Gets the address of the Pyth entropy provider.
     * @return The entropy provider's address.
     */
    function getEntropyProvider() external view returns (address) {
        return i_entropyProvider;
    }

    /**
     * @notice Gets the current sequence number.
     * @return The current sequence number.
     */
    function getCurrentSequenceNumber() external view returns (uint64) {
        return s_currentSequenceNumber;
    }

    /**
     * @notice Gets the current random number.
     * @return The current random number.
     */
    function getCurrentRandomNumber() external view returns (bytes32) {
        return s_currentRandomNumber;
    }
}
