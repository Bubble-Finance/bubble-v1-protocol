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

import { IMonadexV1Raffle } from "../interfaces/IMonadexV1Raffle.sol";

import { MonadexV1Types } from "../../core/library/MonadexV1Types.sol";
import { MonadexV1AuxiliaryLibrary } from "../library/MonadexV1AuxiliaryLibrary.sol";
import { MonadexV1AuxiliaryTypes } from "../library/MonadexV1AuxiliaryTypes.sol";
import { MonadexV1RandomNumberGenerator } from "../raffle/MonadexV1RandomNumberGenerator.sol";

/**
 * @title MonadexV1Raffle
 * @author Monadex Labs -- mgnfy-view
 * @notice The raffle contract allows users to purchase tickets during swaps from the router,
 * enter the weekly draw by burning their tickets, and have a chance at winning from a large
 * prize pool. This contract will be deployed separately, and then the ownership will be trnasferred
 * to the router.
 */
contract MonadexV1Raffle is Ownable, ERC20, MonadexV1RandomNumberGenerator, IMonadexV1Raffle {
    using SafeERC20 for IERC20;

    ///////////////////////
    /// State Variables ///
    ///////////////////////

    // the duration for which the raffle will continue
    // any registrations won't be accepted during this period
    uint256 private constant RAFFLE_DURATION = 1 weeks - 1 days;
    // the registration period begins right after the raffle duration
    // during the registration period, users can register themselves for the weekly draw
    uint256 private constant REGISTRATION_PERIOD = 1 days;
    // the maximum number of winners to draw for the raffle
    uint256 private constant MAX_WINNERS = 6;
    // tiers are layers in which winners will be drawn
    uint256 private constant MAX_TIERS = 3;
    // the first winner is drawn in tier 1 and receives a large prize amount
    uint256 private constant WINNERS_IN_TIER1 = 1;
    // 2 winners are drawn in the second tier, and both of them receive an equal prize amount
    // which is lesser than the amount given to tier 1 winner, but greater than the amount
    // given to tier 3 winners
    uint256 private constant WINNERS_IN_TIER2 = 2;
    // 3 winners from tier 3 receive equal prize amount each, but lesser than the prize amount
    // given to tier 2 winners
    uint256 private constant WINNERS_IN_TIER3 = 3;
    // the maximum number of multipliers which can be applied during ticket purchase
    uint256 private constant MAX_MULTIPLIERS = 3;
    // stores the time when the last draw was made
    uint256 private s_lastTimestamp;
    // users will only be able to purchase tickets if they conduct swaps
    // on pools with supported tokens
    // the amounts of these tokens are collected in the raffle contract
    // and then given out to winners in tiers
    address[] private s_supportedTokens;
    mapping(address token => bool isSupported) private s_isSupportedToken;
    // we use ranges of a fixed size (set during deployment) to register users for a draw
    // imagine a number line extending in both directions with fixed size intervals of 50
    // we begin at 0
    // if you have 100 tickets, you will be put in  ranges, 0-50 and 50-100
    // if you occupy large ranges, you have more chances of winning
    // a random number is selected and can pick users on any random range
    // you increase your chance of being picked if you occupy a large range
    uint256 private immutable i_rangeSize;
    // tracks ranges which are occupied by users
    // for example, range[0] = address("Bob")
    // range[50] = address("Bob")
    // range[100] = address("Alice")
    // here, bob occupies ranges 0-50 and 50-100
    // Alice occupies range 100-150
    mapping(uint256 rangeStart => address user) private s_ranges;
    uint256 private s_currentRangeEnd;
    // each multiplier is associated with a percentage
    // applying a multiplier on an amount is the portion of that amount which
    // will be taken for purchasing tickets
    // the larger the multiplier, the more tickets you get
    // we stick to 3 multipliers, and the percentages associated with each cannot
    // be changed after deployment
    // for example, if you apply multiplier 2 with an associated fee of 1% on amount 10_000
    // you get back 100 tickets
    MonadexV1Types.Fee[MAX_MULTIPLIERS] private s_multipliersToPercentages;
    // the percentage of the total amount that the winner gets for a given tier
    // this applies for all supported tokens
    // for example, winner in tier 1 gets 55% of amounts collected in token A, token B, ... and so on
    // 2 winners in tier 2 both get 15% of amounts collected in token A, token B, ... and so on
    // 3 winners in tier 3 both get 5% of amounts collected in token A, token B, ... and so on
    // 55% + 2 * 15% + 3 * 5% = 100%
    MonadexV1Types.Fee[MAX_TIERS] private s_winningPortions;
    // we use pull or over push
    // users can pull their raffle winnings for a given supported token
    mapping(address user => mapping(address token => uint256 amount)) private s_winnings;

    //////////////
    /// Events ///
    //////////////

    event TicketsPurchased(address indexed receiver, uint256 indexed amount);
    event Registered(address indexed user, uint256 indexed ticketsBurned);
    event WinnersPicked(address[MAX_WINNERS] indexed winners);
    event WinningsClaimed(
        address indexed winner, address indexed token, uint256 amount, address indexed receiver
    );
    event TokenSupported(address indexed token, bool indexed support);

    //////////////
    /// Errors ///
    //////////////

    error MonadexV1Raffle__ZeroAmount();
    error MonadexV1Raffle__TokenNotSupported(address token);
    error MonadexV1Raffle__ZeroTickets();
    error MonadexV1Raffle__NotOpenForRegistration();
    error MonadexV1Raffle__NotEnoughTickets();
    error MonadexV1Raffle__NotEnoughBalance();
    error MonadexV1Raffle__DrawNotAllowedYet();
    error MonadexV1Raffle__InsufficientEntries();
    error MonadexV1Raffle__ZeroWinnings();

    /////////////////
    /// Modifiers ///
    /////////////////

    modifier notZero(uint256 _value) {
        if (_value == 0) revert MonadexV1Raffle__ZeroAmount();
        _;
    }

    ///////////////////
    /// Constructor ///
    ///////////////////

    constructor(
        MonadexV1Types.Fee[MAX_MULTIPLIERS] memory _multipliersToPercentages,
        MonadexV1Types.Fee[MAX_TIERS] memory _winningPortions,
        address[] memory _supportedTokens,
        uint256 _rangeSize
    )
        Ownable(msg.sender)
        ERC20("MonadexV1RaffleTicket", "MDXRT")
    {
        s_lastTimestamp = block.timestamp;
        i_rangeSize = _rangeSize;

        for (uint256 count = 0; count < MAX_MULTIPLIERS; ++count) {
            s_multipliersToPercentages[count] = _multipliersToPercentages[count];
        }

        uint256 length = _supportedTokens.length;
        for (uint256 count = 0; count < length; ++count) {
            s_supportedTokens.push(_supportedTokens[count]);
            s_isSupportedToken[_supportedTokens[count]] = true;
        }

        for (uint256 count = 0; count < MAX_TIERS; ++count) {
            s_winningPortions[count] = _winningPortions[count];
        }
    }

    //////////////////////////
    /// External Functions ///
    //////////////////////////

    /**
     * @notice Allows users to purchase raffle tickets for the given token amount. Purchasing
     * tickets is only possible from the router during swaps.
     * @param _token The token which was swapped for another token.
     * @param _amount The amount of token that was used for swapping.
     * @param _multiplier The multiplier to apply to the ticket purchase.
     * @param _receiver The receiver of tickets.
     * @return The amount of tickets purchased.
     */
    function purchaseTickets(
        address _token,
        uint256 _amount,
        MonadexV1AuxiliaryTypes.Multipliers _multiplier,
        address _receiver
    )
        external
        onlyOwner
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

    /**
     * @notice After the raffle duration ends, a 1 day long registration period will ensue.
     * During this period, users can enter the raffle by burning their tickets. Raffle tickets
     * are only burned in multiples of a fixed size (the range size set during deployment).
     * So the actual amount of tickets burned may be less than or equal to the amount specified
     * as the parameter. Users registering with more tickets will have a higher chance of winning
     * their cut of each tier (it's possible to be the winner in more than one tier for a single user)
     * because they will occupy a larger range on the number line.
     * @param _amount The amount of tickets to register with.
     * @return The actual amount of tickets burned.
     */
    function register(uint256 _amount) external notZero(_amount) returns (uint256) {
        if (!isRegistrationOpen()) revert MonadexV1Raffle__NotOpenForRegistration();
        uint256 slotsToOccupy = _amount / i_rangeSize;
        if (slotsToOccupy == 0) revert MonadexV1Raffle__NotEnoughTickets();

        uint256 balance = balanceOf(msg.sender);
        uint256 ticketsToBurn = slotsToOccupy * i_rangeSize;
        if (ticketsToBurn < balance) revert MonadexV1Raffle__NotEnoughBalance();

        uint256 currentRangeEnd = s_currentRangeEnd;
        for (uint256 count = 0; count < slotsToOccupy; ++count) {
            s_ranges[currentRangeEnd] = msg.sender;
            currentRangeEnd += i_rangeSize;
        }
        s_currentRangeEnd = currentRangeEnd;
        _burn(msg.sender, ticketsToBurn);

        emit Registered(msg.sender, ticketsToBurn);

        return ticketsToBurn;
    }

    /**
     * @notice Selects 6 winners in 3 tiers after the registration period ends, and increases each
     * winner's winnings so that they can claim it whenever they like.
     * @return An array of winners. winners[0] is the winner in tier 1, winners[1] and winners[2]
     * are winners in the 2nd tier, and winners[3], winners[4] and winners[5] are winners in the
     * 3rd tier.
     */
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
        s_currentRangeEnd = 0;
        s_ranges[0] = address(0);
        s_lastTimestamp = block.timestamp;

        _allocateRewards(winners);

        emit WinnersPicked(winners);

        return winners;
    }

    /**
     * @notice Allows winners of previous raffle draws to claim their winnings for supported tokens.
     * @param _token The address of the token to claim winning amount from.
     * @param _receiver The receiver of the winning amount.
     * @return The claimed winning amount.
     */
    function claimWinnings(address _token, address _receiver) external returns (uint256) {
        if (!s_isSupportedToken[_token]) revert MonadexV1Raffle__TokenNotSupported(_token);
        uint256 winnings = s_winnings[msg.sender][_token];
        if (winnings == 0) revert MonadexV1Raffle__ZeroWinnings();

        s_winnings[msg.sender][_token] = 0;
        IERC20(_token).safeTransfer(_receiver, winnings);

        emit WinningsClaimed(msg.sender, _token, winnings, _receiver);

        return winnings;
    }

    /**
     * @notice Gets the raffle duration.
     * @return The raffle duration in seconds.
     */
    function getRaffleDuration() external pure returns (uint256) {
        return RAFFLE_DURATION;
    }

    /**
     * @notice Gets the duration of the registration period.
     * @return The registration period in seconds.
     */
    function getRegistrationPeriod() external pure returns (uint256) {
        return REGISTRATION_PERIOD;
    }

    /**
     * @notice Gets the maximum number of winners that can be drawn.
     * @return The maximum number of raffle winners, combining all tiers.
     */
    function getMaxWinners() external pure returns (uint256) {
        return MAX_WINNERS;
    }

    /**
     * @notice Gets the maximum number of tiers in which winners are drawn.
     * @return The maximum number of tiers.
     */
    function getMaxTiers() external pure returns (uint256) {
        return MAX_TIERS;
    }

    /**
     * @notice Gets the maximum number of multipliers that can be used for purchase.
     * @return The maximum number of multipliers.
     */
    function getMaxMultipliers() external pure returns (uint256) {
        return MAX_MULTIPLIERS;
    }

    /**
     * @notice Gets the UNIX timestamp when the last raffle began.
     * @return The last UNIX timestamp.
     */
    function getLastTimestamp() external view returns (uint256) {
        return s_lastTimestamp;
    }

    /**
     * @notice Gets all supported tokens packed into an array.
     * @return An array of supported tokens.
     */
    function getSupportedTokens() external view returns (address[] memory) {
        return s_supportedTokens;
    }

    /**
     * @notice Checks if the specified token is supported or not.
     * @param _token The token address to check.
     */
    function isSupportedToken(address _token) external view returns (bool) {
        return s_isSupportedToken[_token];
    }

    /**
     * @notice Gets the range size.
     * @return The range size.
     */
    function getRangeSize() external view returns (uint256) {
        return i_rangeSize;
    }

    /**
     * @notice Gets the user at the start of a given range.
     * @param _rangeStart The start of the range.
     */
    function getUserAtRangeStart(uint256 _rangeStart) external view returns (address) {
        return s_ranges[_rangeStart];
    }

    /**
     * @notice Gets the end of the current range.
     * @return The current range's end.
     */
    function getCurrentRangeEnd() external view returns (uint256) {
        return s_currentRangeEnd;
    }

    /**
     * @notice Gets the percentage of fee taken for each multiplier.
     * @param _multiplier The multiplier.
     * @return A fee struct, with numerator and denominator fields.
     */
    function getMultipliersToPercentages(MonadexV1AuxiliaryTypes.Multipliers _multiplier)
        external
        view
        returns (MonadexV1Types.Fee memory)
    {
        return _getMultiplierToPercentage(_multiplier);
    }

    /**
     * @notice Gets the winnings of a given user for a given token.
     * @param _user The user's address.
     * @param _token The supported token.
     * @return The user's winnings.
     */
    function getWinnings(address _user, address _token) external view returns (uint256) {
        return s_winnings[_user][_token];
    }

    ////////////////////////
    /// Public Functions ///
    ////////////////////////

    /**
     * @notice Gets the amount of tickets based on the given amount and multiplier.
     * @param _amount The amount to use for ticket purchase.
     * @param _multiplier The multiplier to apply to the amount.
     * @return The number of tickets to purchase.
     */
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

    /**
     * @notice Checks if the registration period is open.
     * @return True if the registration period is open, false otherwise.
     */
    function isRegistrationOpen() public view returns (bool) {
        if (block.timestamp < s_lastTimestamp + RAFFLE_DURATION) return false;
        else return true;
    }

    //////////////////////////
    /// Internal Functions ///
    //////////////////////////

    /**
     * @notice Gets the percentage of fee taken for each multiplier.
     * @param _multiplier The multiplier.
     * @return A fee struct, with numerator and denominator fields.
     */
    function _getMultiplierToPercentage(MonadexV1AuxiliaryTypes.Multipliers _multiplier)
        internal
        view
        returns (MonadexV1Types.Fee memory)
    {
        if (_multiplier == MonadexV1AuxiliaryTypes.Multipliers.Multiplier1) {
            return s_multipliersToPercentages[0];
        } else if (_multiplier == MonadexV1AuxiliaryTypes.Multipliers.Multiplier2) {
            return s_multipliersToPercentages[1];
        } else {
            return s_multipliersToPercentages[2];
        }
    }

    /**
     * @notice Selects a rnadom range based on the given random word and the current range end.
     * @param _randomWord The random word obtained from a VRF service.
     * @param _currentRangeEnd The current range end.
     * @return The selected range.
     */
    function _getSelectedRange(
        uint256 _randomWord,
        uint256 _currentRangeEnd
    )
        internal
        view
        returns (uint256)
    {
        // get the hitpoint. This point lies within a range
        // for example, if the current range end is 600 with range size of 50
        // the hitpoint may lie within any range, say 55, or 89, etc
        uint256 hitPoint = _randomWord % (_currentRangeEnd);
        // convert the hitpoint so that it points to the start of the range
        // for example, if the hitpoint is 55, then it should point to 50 as the range start
        // selectedRange = 55 - (55 % 50) = 50
        uint256 selectedRange = hitPoint - (hitPoint % i_rangeSize);

        return selectedRange;
    }

    /**
     * @notice A helper function that selects 6 winners using a random word.
     * @param _randomWord The random word obtained from a VRF service.
     * @return An array of winners.
     */
    function _selectWinners(uint256 _randomWord) internal returns (address[6] memory) {
        address[MAX_WINNERS] memory winners;
        uint256 currentRangeEnd = s_currentRangeEnd - i_rangeSize;

        // after a winner has been picked, we swap out the winner with the last user on the number
        // line and decrement the currentRangeEnd by rangeSize
        for (uint256 count = 0; count < MAX_WINNERS; ++count) {
            uint256 selectedRange = _getSelectedRange(_randomWord, currentRangeEnd);
            winners[count] = s_ranges[selectedRange];
            s_ranges[selectedRange] = s_ranges[currentRangeEnd];
            if (count != 5) currentRangeEnd -= i_rangeSize;
        }

        return winners;
    }

    /**
     * @notice Allocates tokens as winnings to the raffle winners.
     * @param _winners The winners drawn.
     */
    function _allocateRewards(address[MAX_WINNERS] memory _winners) internal {
        address[] memory supportedTokens = s_supportedTokens;
        uint256 numberOfSupportedTokens = supportedTokens.length;
        uint256[] memory tokenBalances;
        MonadexV1Types.Fee[MAX_TIERS] memory winningPortions = s_winningPortions;
        MonadexV1Types.Fee memory portion;

        for (uint256 count = 0; count < numberOfSupportedTokens; ++count) {
            tokenBalances[count] = IERC20(supportedTokens[count]).balanceOf(address(this));
        }

        for (uint256 count = 0; count < MAX_WINNERS; ++count) {
            if (count == WINNERS_IN_TIER1 - 1) portion = winningPortions[0];
            else if (count < WINNERS_IN_TIER1 + WINNERS_IN_TIER2) portion = winningPortions[1];
            else portion = winningPortions[2];

            for (uint256 newCount = 0; newCount < numberOfSupportedTokens; ++newCount) {
                uint256 tokenBalance = tokenBalances[newCount];
                s_winnings[_winners[count]][supportedTokens[newCount]] +=
                    (tokenBalance * portion.numerator) / portion.denominator;
            }
        }
    }
}
