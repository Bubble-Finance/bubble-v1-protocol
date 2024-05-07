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

import { Ownable } from "../../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { IERC20 } from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from
    "../../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { MonadexV1Types } from "../../core/library/MonadexV1Types.sol";
import { MonadexV1AuxiliaryLibrary } from "../library/MonadexV1AuxiliaryLibrary.sol";
import { MonadexV1AuxiliaryTypes } from "../library/MonadexV1AuxiliaryTypes.sol";
import { MonadexV1RandomNumberGenerator } from "../raffle/MonadexV1RandomNumberGenerator.sol";

/**
 * @title MonadexV1Raffle
 * @author Monadex Labs -- Ola Hamid, mgnfy-view
 * @notice The raffle contract allows users to purchase tickets during swaps from the router,
 * enter the weekly draw by burning their tickets, and have a chance at winning from a large
 * prize pool
 */
contract MonadexV1Raffle is MonadexV1RandomNumberGenerator, Ownable, ERC20 {
    using SafeERC20 for IERC20;

    ///////////////////////
    /// State Variables ///
    ///////////////////////

    uint256 private constant RAFFLE_DURATION = 1 weeks - 1 days;
    uint256 private constant REGISTRATION_PERIOD = 1 days;
    uint256 private constant MAX_WINNERS = 6;
    uint256 private constant MAX_TIERS = 3;
    uint256 private constant TIER1_WINNERS = 1;
    uint256 private constant TIER2_WINNERS = 2;
    uint256 private constant TIER3_WINNERS = 3;
    uint256 private constant MAX_MULTIPLIERS = 3;
    address private immutable i_router;
    uint256 private s_lastTimestamp;
    MonadexV1Types.Fee[MAX_MULTIPLIERS] private s_percentages;
    MonadexV1Types.Fee[MAX_TIERS] private s_winningPortions;
    address[] private s_supportedTokens;
    mapping(address token => bool isSupported) private s_isSupportedToken;
    uint256 private i_rangeSize;
    mapping(uint256 rangeStart => address user) private s_ranges;
    uint256 private s_currentRangeEnd;
    mapping(address user => mapping(address token => uint256 amount)) private s_winnings;

    //////////////
    /// Events ///
    //////////////

    event TokenSupported(address indexed token, bool indexed support);
    event WinningsClaimed(
        address indexed winner, address indexed token, uint256 amount, address indexed receiver
    );
    event Registered(address indexed user, uint256 indexed ticketsBurned);
    event WinnersPicked(address[MAX_WINNERS] indexed winners);
    event TicketsPurchased(address receiver, uint256 amount);

    //////////////
    /// Errors ///
    //////////////

    error MonadexV1Raffle__ZeroAddress();
    error MonadexV1Raffle__TokenNotSupported(address token);
    error MonadexV1Raffle__ZeroValue();
    error MonadexV1Raffle__NotRouter(address caller);
    error MonadexV1Raffle__ZeroTickets();
    error MonadexV1Raffle__RaffleIntervalNotPassed();
    error MonadexV1Raffle__ZeroWinnings();
    error MonadexV1Raffle__InsufficientTickets(uint256 tickets);
    error MonadexV1Raffle__NotOpen();
    error MonadexV1Raffle__NotEnoughTickets();
    error MonadexV1Raffle__NotEnoughBalance();
    error MonadexV1Raffle__DrawNotAllowedYet();
    error MonadexV1Raffle__InsufficientEntries();

    /////////////////
    /// Modifiers ///
    /////////////////

    modifier notZero(uint256 _value) {
        if (_value == 0) revert MonadexV1Raffle__ZeroValue();
        _;
    }

    modifier onlyRouter(address _caller) {
        if (_caller != i_router) revert MonadexV1Raffle__NotRouter(_caller);
        _;
    }

    modifier onlyAfterRaffleDuration(uint256 _timestamp) {
        if (_timestamp < s_lastTimestamp + RAFFLE_DURATION) {
            revert MonadexV1Raffle__RaffleIntervalNotPassed();
        }
        _;
    }

    ///////////////////
    /// Constructor ///
    ///////////////////

    constructor(
        address _router,
        MonadexV1Types.Fee[MAX_MULTIPLIERS] memory _percentages,
        MonadexV1Types.Fee[MAX_TIERS] memory _winningPortions,
        address[] memory _supportedTokens,
        uint256 _rangeSize
    )
        Ownable(msg.sender)
        ERC20("MonadexV1RaffleTicket", "MDXRT")
    {
        i_router = _router;
        s_lastTimestamp = block.timestamp;
        i_rangeSize = _rangeSize;
        s_currentRangeEnd = 0;

        for (uint256 count = 0; count < MAX_MULTIPLIERS; ++count) {
            s_percentages[count] = _percentages[count];
        }

        for (uint256 count = 0; count < _supportedTokens.length; ++count) {
            s_supportedTokens[count] = _supportedTokens[count];
            s_isSupportedToken[_supportedTokens[count]] = true;
        }

        for (uint256 count = 0; count < MAX_TIERS; ++count) {
            s_winningPortions[count] = _winningPortions[count];
        }
    }

    //////////////////////////
    /// External Functions ///
    //////////////////////////

    function purchaseTickets(
        address _token,
        uint256 _amount,
        MonadexV1AuxiliaryTypes.Multipliers _multiplier,
        address _receiver
    )
        external
        onlyRouter(msg.sender)
        notZero(_amount)
        returns (uint256)
    {
        if (!s_isSupportedToken[_token]) revert MonadexV1Raffle__TokenNotSupported(_token);
        uint256 tickets = previewPurchase(_amount, _multiplier);
        if (tickets == 0) revert MonadexV1Raffle__ZeroTickets();
        _mint(_receiver, tickets);

        emit TicketsPurchased(_receiver, tickets);

        return tickets;
    }

    function register(uint256 _amount) external notZero(_amount) returns (uint256) {
        if (!isRaffleOpen()) revert MonadexV1Raffle__NotOpen();
        uint256 slotsToOccupy = _amount / i_rangeSize;
        if (slotsToOccupy == 0) revert MonadexV1Raffle__NotEnoughTickets();

        uint256 balance = balanceOf(msg.sender);
        uint256 ticketsToBurn = slotsToOccupy * i_rangeSize;
        if (ticketsToBurn < balance) revert MonadexV1Raffle__NotEnoughBalance();
        _burn(msg.sender, ticketsToBurn);

        uint256 currentRangeEnd = s_currentRangeEnd;
        for (uint256 count = 0; count < slotsToOccupy; ++count) {
            s_ranges[currentRangeEnd] = msg.sender;
            currentRangeEnd += i_rangeSize;
        }
        s_currentRangeEnd = currentRangeEnd;

        emit Registered(msg.sender, ticketsToBurn);

        return ticketsToBurn;
    }

    function drawWinners() external returns (address[MAX_WINNERS] memory) {
        if (block.timestamp < s_lastTimestamp + RAFFLE_DURATION + REGISTRATION_PERIOD) {
            revert MonadexV1Raffle__DrawNotAllowedYet();
        }
        if (s_currentRangeEnd < MAX_WINNERS * i_rangeSize) {
            revert MonadexV1Raffle__InsufficientEntries();
        }

        uint256 randomWord = _requestRandomWord();
        address[MAX_WINNERS] memory winners;
        winners = _selectWinners(randomWord);
        _allocateRewards(winners);

        s_currentRangeEnd = 0;
        s_ranges[0] = address(0);
        s_lastTimestamp = block.timestamp;

        emit WinnersPicked(winners);

        return winners;
    }

    function claimWinnings(address _token, address _receiver) external returns (uint256) {
        if (!s_isSupportedToken[_token]) revert MonadexV1Raffle__TokenNotSupported(_token);
        uint256 winnings = s_winnings[msg.sender][_token];
        if (winnings == 0) revert MonadexV1Raffle__ZeroWinnings();

        IERC20(_token).safeTransfer(_receiver, winnings);

        emit WinningsClaimed(msg.sender, _token, winnings, _receiver);

        return winnings;
    }

    function getLastTimestamp() external view returns (uint256) {
        return s_lastTimestamp;
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return s_supportedTokens;
    }

    function isSupportedToken(address _token) external view returns (bool) {
        return s_isSupportedToken[_token];
    }

    function getWinnings(address _user, address _token) external view returns (uint256) {
        return s_winnings[_user][_token];
    }

    function getCurrentRange() external view returns (uint256) {
        return s_currentRangeEnd;
    }

    ////////////////////////
    /// Public Functions ///
    ////////////////////////

    function previewPurchase(
        uint256 _amount,
        MonadexV1AuxiliaryTypes.Multipliers _multiplier
    )
        public
        view
        returns (uint256)
    {
        return MonadexV1AuxiliaryLibrary.calculateAmountOfTickets(
            _amount, _getMultiplierToPercentage(_multiplier)
        );
    }

    function isRaffleOpen() public view returns (bool) {
        if (block.timestamp < s_lastTimestamp + RAFFLE_DURATION) return true;
        else return false;
    }

    //////////////////////////
    /// Internal Functions ///
    //////////////////////////

    function _getMultiplierToPercentage(MonadexV1AuxiliaryTypes.Multipliers _multiplier)
        internal
        view
        returns (MonadexV1Types.Fee memory)
    {
        if (_multiplier == MonadexV1AuxiliaryTypes.Multipliers.Multiplier1) {
            return s_percentages[0];
        } else if (_multiplier == MonadexV1AuxiliaryTypes.Multipliers.Multiplier2) {
            return s_percentages[1];
        } else {
            return s_percentages[2];
        }
    }

    function _getSelectedRange(
        uint256 _randomWord,
        uint256 _currentRangeEnd
    )
        internal
        returns (uint256)
    {
        uint256 hitPoint = _randomWord % (_currentRangeEnd);
        uint256 selectedRange = hitPoint - (hitPoint % i_rangeSize);

        return selectedRange;
    }

    function _selectWinners(uint256 _randomWord) internal returns (address[6] memory) {
        address[MAX_WINNERS] memory winners;
        uint256 currentRangeEnd = s_currentRangeEnd - i_rangeSize;

        for (uint8 count = 0; count < MAX_WINNERS; ++count) {
            uint256 selectedRange = _getSelectedRange(_randomWord, currentRangeEnd);
            winners[count] = s_ranges[selectedRange];
            s_ranges[selectedRange] = s_ranges[currentRangeEnd];
            if (count != 5) currentRangeEnd -= i_rangeSize;
        }

        return winners;
    }

    function _allocateRewards(address[MAX_WINNERS] memory _winners) internal {
        address[] memory supportedTokens = s_supportedTokens;
        uint256 numberOfSupportedTokens = supportedTokens.length;
        MonadexV1Types.Fee[MAX_TIERS] memory winningPortions = s_winningPortions;
        MonadexV1Types.Fee memory portion;

        for (uint8 count = 0; count < MAX_WINNERS; ++count) {
            if (count == TIER1_WINNERS - 1) portion = winningPortions[0];
            else if (count < TIER1_WINNERS + TIER2_WINNERS) portion = winningPortions[1];
            else portion = winningPortions[2];
            for (uint8 newCount = 0; newCount < numberOfSupportedTokens; ++newCount) {
                uint256 tokenBalance = IERC20(supportedTokens[newCount]).balanceOf(address(this));
                s_winnings[_winners[count]][supportedTokens[newCount]] +=
                    (tokenBalance * portion.numerator) / portion.denominator;
            }
        }
    }
}
