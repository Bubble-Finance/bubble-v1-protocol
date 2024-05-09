// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
// LAYOUT OVERVIEW
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

/// @title MonadexV1AirdropManager
/// @author Ola Hamid
/// @notice This contract manages the airdrop process for the Monadex protocol, utilizing a Merkle tree for efficient eligibility verification.
/// @notice Participants submit their proof of eligibility, which is verified against the Merkle root. Upon successful verification, participants can claim their airdrop tokens.

import { MerkleProof } from
    "../../../lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

import { BitMaps } from "../../../lib/openzeppelin-contracts/contracts/utils/structs/BitMaps.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
//NOTE: Limitation add non reentrancy

contract MonadexV1AirdropManager is Ownable, ReentrancyGuard {
    using Address for address;
    using SafeERC20 for IERC20;

    /////////////////////
    ///state variables///
    /////////////////////
    bytes32 public merkleRoot;
    BitMaps.BitMap private _airdropLists;
    address[] public eligibleAddresses;
    address[] private s_Tokens;

    uint256 public maxAddressLimit;
    uint256 public claimAmount;

    mapping(address => bool isSupported) public m_supportedToken;
    mapping(address => bytes32) public m_claimProof;
    mapping(address => bool) public m_hasClaimed;

    ///////////
    ///ERROR///
    //////////
    error Monadex_UnsupportedAirdropToken(address token);
    error Monadex_ZeroAddressError();
    error Monadex_maxAddressLimit(uint256 maxAddressLimit, uint256 receiverLength);
    // error Monadex_IneligibleAddressError();
    error Monadex_InvalidMekleproofError();
    error Monadex_newAddressAlreadyExisted();
    error Monadex_HasClaimedError();
    error Monadex_sameTokenAddrAlreadyAdded();
    error Monadex_moreThanZeroAmount();

    ///////////
    ///Event///
    //////////
    event E_TokenToClaim(address token, address claimer);
    event E_directTokenToclaim(address token, uint256 amount);
    // event E_addNewUserAddress(address newAddr);
    event E_addAirdropfund(address token, uint256 amountToAdd);
    event E_addToken(address token);

    constructor(
        uint256 _claimAmountPerWallet,
        uint256 _maxAddressLimit,
        bytes32 _merkleRoot
    )
        Ownable(msg.sender)
    {
        claimAmount = _claimAmountPerWallet;
        maxAddressLimit = _maxAddressLimit;
        merkleRoot = _merkleRoot;
    }

    function addToken(address newToken) external onlyOwner {
        if (newToken == address(0)) {
            revert Monadex_ZeroAddressError();
        }
        //tackle that users dont add the same new token multiple times
        if (m_supportedToken[newToken] == true) {
            revert Monadex_sameTokenAddrAlreadyAdded();
        }
        m_supportedToken[newToken] = true;

        s_Tokens.push(newToken);

        emit E_addToken(newToken);
    }

    function addAirdropFund(
        address supportedToken,
        uint256 totalAmountToAirdrop
    )
        external
        onlyOwner
        nonReentrant
    {
        if (m_supportedToken[supportedToken] != true) {
            revert Monadex_UnsupportedAirdropToken(supportedToken);
        }

        IERC20 token = IERC20(supportedToken);
        if (totalAmountToAirdrop <= 0) {
            revert Monadex_moreThanZeroAmount();
        }
        token.safeTransferFrom(msg.sender, address(this), totalAmountToAirdrop);

        emit E_addAirdropfund(supportedToken, totalAmountToAirdrop);
    }
    //limitations gas efficiency from .transfer function

    function directAirdrop(
        address supportedToken,
        address[] memory receiver,
        uint256 amount,
        bytes32[] calldata proof,
        uint256 index
    )
        external
        onlyOwner
        nonReentrant
    {
        if (m_supportedToken[supportedToken] != true) {
            revert Monadex_UnsupportedAirdropToken(supportedToken);
        }
        if (receiver.length > maxAddressLimit) {
            revert Monadex_maxAddressLimit(maxAddressLimit, receiver.length);
        }
        IERC20 token = IERC20(supportedToken);

        for (uint256 i = 0; i < receiver.length; ++i) {
            //the below line verifies that proof and address from the using merkleProof in the verifyProof function
            verifyProof(receiver[i], proof, index, claimAmount);
            BitMaps.setTo(_airdropLists, index, true);
            token.safeTransfer(receiver[i], amount);
        }

        emit E_directTokenToclaim(supportedToken, amount);
    }
    //limitation users can claim more than once- solved

    function claimAirdrop(
        address supportedToken,
        bytes32[] calldata proof,
        uint256 index
    )
        external
        nonReentrant
    {
        //check for supported token
        m_claimProof[msg.sender] = keccak256(abi.encodePacked(proof));
        if (m_supportedToken[supportedToken] != true) {
            revert Monadex_UnsupportedAirdropToken(supportedToken);
        }
        //this verify if the airdrop have already been claimed from the bitmap, through the index
        if (BitMaps.get(_airdropLists, index)) {
            revert Monadex_HasClaimedError();
        }
        //the below line verifies that proof and address from the using merkleProof in the verifyProof function
        verifyProof(msg.sender, proof, index, claimAmount);
        // set index to true in the bitMap contract
        BitMaps.setTo(_airdropLists, index, true);
        IERC20 token = IERC20(supportedToken);

        emit E_TokenToClaim(supportedToken, msg.sender);
        token.safeTransfer(msg.sender, claimAmount);
    }

    function verifyProof(
        address user,
        bytes32[] calldata proof,
        uint256 index,
        uint256 amount
    )
        private
        view
    {
        //check for zero address error
        if (user == address(0)) {
            revert Monadex_ZeroAddressError();
        }
        bytes32 leaf = keccak256(abi.encode(user, index, amount));

        if (!MerkleProof.verify(proof, merkleRoot, leaf)) {
            revert Monadex_InvalidMekleproofError();
        }
    }
    /////////////////////
    ///getter function///
    /////////////////////

    function getNewToken(uint256 TokenID) public view returns (address) {
        return s_Tokens[TokenID];
    }
}

// bytes32 leaf = keccak256(abi.encode(msg.sender));
// //adding address tp proof...m_claimproof mapping

// if (!MerkleProof.verify(proof, merkleRoot, leaf)) {
//     revert Monadex_InvalidMekleproofError();
// }
