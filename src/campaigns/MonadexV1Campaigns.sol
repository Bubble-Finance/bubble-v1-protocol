// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { ERC20Launchable } from "./ERC20Launchable.sol";
import { Owned } from "@solmate/auth/Owned.sol";

import { IMonadexV1Campaigns } from "../interfaces/IMonadexV1Campaigns.sol";

import { MonadexV1Types } from "../library/MonadexV1Types.sol";

contract MonadexV1Campaigns is Owned, IMonadexV1Campaigns {
    uint16 private constant BPS = 10_000;

    uint256 private s_minimumTokenTotalSupply;
    uint256 private s_minimumVirutalNativeReserve;
    uint256 private s_minimumNativeAmountToRaise;

    uint16 private s_feeInBasisPoints;
    uint256 private s_feeCollected;

    uint256 private s_tokenCreatorRewardPercentageInBasisPoints;

    address private immutable s_monadexV1Router;

    mapping(address token => MonadexV1Types.TokenDetails tokenDetails) private s_tokenDetails;

    event FeesCollected(uint256 amount, address to);
    event TokenCreated(address token);

    error MonadexV1Campaigns__DeadlinePasssed(uint256 deadline);
    error MonadexV1Campaigns__InsufficientFeesToCollect();
    error MonadexV1Campaigns__TransferFailed();
    error MonadexV1Campaigns__InvalidTokenCreationparams(MonadexV1Types.TokenDetails tokenDetails);

    modifier beforeDeadline(uint256 _deadline) {
        if (_deadline < block.timestamp) revert MonadexV1Campaigns__DeadlinePasssed(_deadline);
        _;
    }

    constructor(
        uint256 _minimumTokenTotalSupply,
        uint256 _minimumVirutalNativeReserve,
        uint256 _minimumNativeAmountToRaise,
        uint16 _feeInBasisPoints,
        uint256 _tokenCreatorRewardPercentageInBasisPoints
    )
        Owned(msg.sender)
    {
        s_minimumTokenTotalSupply = _minimumTokenTotalSupply;
        s_minimumVirutalNativeReserve = _minimumVirutalNativeReserve;
        s_minimumNativeAmountToRaise = _minimumNativeAmountToRaise;
        s_feeInBasisPoints = _feeInBasisPoints;
        s_tokenCreatorRewardPercentageInBasisPoints = _tokenCreatorRewardPercentageInBasisPoints;
    }

    function collectFees(address _to, uint256 _amount) external onlyOwner {
        if (_amount > s_feeCollected) revert MonadexV1Campaigns__InsufficientFeesToCollect();

        (bool success,) = payable(_to).call{ value: _amount }("");
        if (!success) revert MonadexV1Campaigns__TransferFailed();

        emit FeesCollected(_amount, _to);
    }

    function createToken(
        MonadexV1Types.TokenDetails calldata _tokenDetails,
        uint256 _deadline
    )
        external
        payable
        beforeDeadline(_deadline)
        returns (address)
    {
        if (
            _tokenDetails.creator != msg.sender
                || _tokenDetails.totalSupply < s_minimumTokenTotalSupply
                || _tokenDetails.virtualNativeReserve < s_minimumVirutalNativeReserve
                || _tokenDetails.targetNativeReserve - _tokenDetails.virtualNativeReserve
                    < s_minimumNativeAmountToRaise
        ) revert MonadexV1Campaigns__InvalidTokenCreationparams(_tokenDetails);

        ERC20Launchable token =
            new ERC20Launchable(_tokenDetails.name, _tokenDetails.symbol, _tokenDetails.totalSupply);
        s_tokenDetails[address(token)] = _tokenDetails;

        emit TokenCreated(address(token));

        buyTokens(address(token), 0, _deadline);

        return address(token);
    }

    function buyTokens(
        address _token,
        uint256 _minimumAmountToReceive,
        uint256 _deadline
    )
        public
        payable
        beforeDeadline(_deadline)
    { }
}
