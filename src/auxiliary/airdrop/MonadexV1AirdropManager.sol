// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
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
/// @notice ....
/// @notice

import { MerkleProof } from
    "../../../lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
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
    address[] public eligibleAddresses;
    address[] private s_Tokens;
    mapping(address => bool isSupported) public m_supportedToken;
    // mapping(address => bool eligible) public m_eligibleUser;
    mapping(address => bool) public m_hasClaimed;
    uint256 public maxAddressLimit;
    uint256 public claimAmount;

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
        token.safeTransferFrom(msg.sender, address(this), totalAmountToAirdrop);

        emit E_addAirdropfund(supportedToken, totalAmountToAirdrop);
    }
    //limitations gas efficiency from .transfer function

    function directAirdrop(
        address supportedToken,
        address[] memory receiver,
        uint256 amount,
        bytes32[] calldata proof
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

        for (uint256 i = 0; i < receiver.length; i++) {
            // require(receiver[i] != address(0));
            if (receiver[i] == address(0)) {
                revert Monadex_ZeroAddressError();
            }
            bytes32 leaf = keccak256(abi.encode(msg.sender));
            if (!MerkleProof.verify(proof, merkleRoot, leaf)) {
                revert Monadex_InvalidMekleproofError();
            }

            token.safeTransfer(receiver[i], amount);
        }

        emit E_directTokenToclaim(supportedToken, amount);
    }
    //limitation users can claim more than once

    function claimAirdrop(address supportedToken, bytes32[] calldata proof) external nonReentrant {
        bytes32 leaf = keccak256(abi.encode(msg.sender));
        if (!MerkleProof.verify(proof, merkleRoot, leaf)) {
            revert Monadex_InvalidMekleproofError();
        }
        if (m_supportedToken[supportedToken] != true) {
            revert Monadex_UnsupportedAirdropToken(supportedToken);
        }
        // if (m_eligibleUser[msg.sender] != true) {
        //     revert Monadex_IneligibleAddressError();
        // }
        if (m_hasClaimed[msg.sender] == true) {
            revert Monadex_HasClaimedError();
        }
        m_hasClaimed[msg.sender] = true;
        IERC20 token = IERC20(supportedToken);
        token.safeTransfer(msg.sender, claimAmount);

        emit E_TokenToClaim(supportedToken, msg.sender);
    }

    // function addEligibleAddress(address newAddress) public onlyOwner {
    //     if (m_eligibleUser[newAddress]) {
    //         revert Monadex_newAddressAlreadyExisted();
    //     }
    //     if (newAddress == address(0)) {
    //         revert Monadex_ZeroAddressError();
    //     }
    //     m_eligibleUser[newAddress] = true;
    //     eligibleAddresses.push(newAddress);

    //     emit E_addNewUserAddress(newAddress);
    // }

    /////////////////////
    ///getter function///
    /////////////////////
    function getNewToken(uint256 TokenID) public view returns (address) {
        return s_Tokens[TokenID];
    }
}
