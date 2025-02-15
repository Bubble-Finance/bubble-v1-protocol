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
pragma solidity 0.8.25;

import { IVotes } from
    "lib/openzeppelin-contracts/contracts/governance/extensions/GovernorVotes.sol";

import { Governor } from "lib/openzeppelin-contracts/contracts/governance/Governor.sol";
import { GovernorCountingSimple } from
    "lib/openzeppelin-contracts/contracts/governance/extensions/GovernorCountingSimple.sol";
import { GovernorSettings } from
    "lib/openzeppelin-contracts/contracts/governance/extensions/GovernorSettings.sol";
import {
    GovernorTimelockControl,
    TimelockController
} from "lib/openzeppelin-contracts/contracts/governance/extensions/GovernorTimelockControl.sol";
import { GovernorVotes } from
    "lib/openzeppelin-contracts/contracts/governance/extensions/GovernorVotes.sol";
import { GovernorVotesQuorumFraction } from
    "lib/openzeppelin-contracts/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";

/// @title MonadexV1Governor.
/// @author Monadex Labs -- Ola hamid.
/// @notice Facilitates on-chain governance with voting and timelock control.
contract MonadexV1Governor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    ///////////////////
    /// Constructor ///
    ///////////////////

    /// @notice Initializes the Governor. Fully configurable during deployment.
    /// @param _token The token to vote with. This will be the $MDX token.
    /// @param _timelock The timelock which will add a delay before executing proposals.
    /// @param _initialVotingDelay The delay after which votes can be cast.
    /// @param _initialVotingPeriod The duration for which the voting will last.
    /// @param _initialProposalThreshold The minimum amount of $MDX you should have to propose.
    /// @param _quorum The minimum percentage of voters that should be involved in the voting.
    constructor(
        IVotes _token,
        TimelockController _timelock,
        uint48 _initialVotingDelay,
        uint32 _initialVotingPeriod,
        uint256 _initialProposalThreshold,
        uint256 _quorum
    )
        Governor("MonadexV1Governor")
        GovernorSettings(_initialVotingDelay, _initialVotingPeriod, _initialProposalThreshold)
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(_quorum)
        GovernorTimelockControl(_timelock)
    { }

    // The following functions are overrides required by Solidity.

    //////////////////////////
    /// Internal Functions ///
    //////////////////////////

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        override(Governor, GovernorTimelockControl)
        returns (uint48)
    {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        override(Governor, GovernorTimelockControl)
    {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        override(Governor, GovernorTimelockControl)
        returns (uint256)
    {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    ///////////////////////////////
    /// View and Pure Functions ///
    ///////////////////////////////

    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    function quorum(
        uint256 blockNumber
    )
        public
        view
        override(Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function state(
        uint256 proposalId
    )
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(
        uint256 proposalId
    )
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }
}
