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

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { IEntropy } from "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import { IEntropyConsumer } from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import { IPyth } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

import { IMonadexV1Raffle } from "../interfaces/IMonadexV1Raffle.sol";

import { MonadexV1Library } from "../library/MonadexV1Library.sol";
import { MonadexV1Types } from "../library/MonadexV1Types.sol";
import { MonadexV1RaffleEntropy } from "./MonadexV1RaffleEntropy.sol";
import { MonadexV1RafflePriceCalculator } from "./MonadexV1RafflePriceCalculator.sol";

/// @title MonadexV1Raffle.
/// @author Monadex Labs -- mgnfy-view.
/// @notice The raffle contract allows users to purchase tickets during swaps from the router,
/// enter the weekly draw by burning their tickets, and have a chance at winning from a large
/// prize pool. This contract will be deployed separately, and then registered in the router.
/// Raffle will be owned by the protocol team multisig in the initial stages, and by the Monadex
/// DAO later on.
contract MonadexV1Raffle is
    ERC20,
    Ownable,
    MonadexV1RafflePriceCalculator,
    MonadexV1RaffleEntropy,
    IMonadexV1Raffle
{
    using SafeERC20 for IERC20;

    ///////////////////////
    /// State Variables ///
    ///////////////////////

    /// @dev The duration for which the raffle will continue.
    /// Any registrations won't be accepted during this period.
    uint256 private constant RAFFLE_DURATION = 6 days;
    /// @dev The registration period begins right after the raffle duration,
    /// and lasts for a day.
    /// During this period, users can register themselves for the weekly draw.
    uint256 private constant REGISTRATION_PERIOD = 1 days;
    /// @dev The maximum number of winners to draw for the raffle.
    uint256 private constant MAX_WINNERS = 6;
    /// @dev Tiers are layers in which winners will be drawn.
    /// There are a maximum of 3 tiers.
    uint256 private constant MAX_TIERS = 3;
    /// @dev One winner is drawn in tier 1 and receives a large prize amount.
    uint256 private constant WINNERS_IN_TIER1 = 1;
    /// @dev 2 winners are drawn in the second tier, and both of them receive an equal prize amount
    /// which is lesser than the amount given to the tier 1 winner, but greater than the amount
    /// given to tier 3 winners.
    uint256 private constant WINNERS_IN_TIER2 = 2;
    /// @dev 3 winners from tier 3 receive equal prize amount each, but lesser than the prize amount
    /// given to tier 2 winners.
    uint256 private constant WINNERS_IN_TIER3 = 3;
    /// @dev We use ranges of a fixed size to register users for draw.
    /// Imagine a number line extending in one direction with fixed size intervals of 50.
    /// We begin at 0.
    /// If you have 100 tickets, you will be put in  ranges, 0-50 and 50-100.
    /// If you occupy a lot of ranges, you have more chances of winning.
    /// A random number is selected and can pick users on any random range.
    /// You increase your chances of being picked if you occupy a large range.
    /// The range size is given by: 10 ** token decimals (by default 18).
    uint256 private constant RANGE_SIZE = 1e18;
    /// @dev The maximum number of tokens that can be used for raffle.
    uint256 private constant MAX_SUPPORTED_TOKENS = 5;
    /// @dev We need to store the router's address to ensure that purchases are made from the router
    /// only.
    address private s_router;
    /// @dev Stores the UNIX timestamp (in seconds) of the time when the last draw was made.
    uint256 private s_lastTimestamp;
    /// @dev Users will only be able to purchase tickets if they conduct swaps
    /// on pools with supported tokens.
    /// The amounts of these tokens are collected in this contract
    /// and then given out to winners in different tiers.
    address[] private s_supportedTokens;
    /// @dev A mapping of supported tokens for cheaper access.
    mapping(address token => bool isSupported) private s_isSupportedToken;
    /// @dev Tracks ranges which are occupied by users.
    /// For example, range[0] = address("Bob"),
    /// range[50e18] = address("Bob"),
    /// range[100e18] = address("Alice").
    /// Here, Bob occupies ranges 0-50e18 and 50e18-100e18.
    /// Alice occupies range 100e18-150e18.
    mapping(uint256 rangeStart => address user) private s_ranges;
    /// @dev Tracks the currrent range for the week's registrations.
    /// The next registration will be put in this range.
    uint256 private s_currentRangeEnd;
    /// @dev The percentage of the total amount that the winner gets for a given tier.
    /// This applies for all supported tokens.
    /// For example, winner in tier 1 gets 45% of amounts collected in token A, token B, ... and so on.
    /// 2 winners in tier 2 both get 20% of amounts collected in token A, token B, ... and so on.
    /// 3 winners in tier 3 both get 5% of amounts collected in token A, token B, ... and so on.
    /// 45% + (2 * 20%) + (3 * 5%) = 100%
    MonadexV1Types.Fraction[MAX_TIERS] private s_winningPortions;
    /// @dev We use the pull over push pattern.
    /// Users can pull their raffle winnings for a given supported token.
    mapping(address user => mapping(address token => uint256 amount)) private s_winnings;
    /// @dev The minimum number of registrations required before a draw can be made.
    uint256 private s_minimumParticipants;

    //////////////
    /// Events ///
    //////////////

    event RouterAddressSet(address indexed router);
    event TicketsPurchased(
        address token, uint256 amount, address indexed receiver, uint256 indexed ticketsMinted
    );
    event Registered(address indexed user, uint256 indexed ticketsBurned);
    event RandomNumberRequested(uint64 indexed sequenceNumber);
    event WinnersPicked(address[MAX_WINNERS] indexed winners);
    event WinningsClaimed(address indexed winner, address indexed token, uint256 amount);
    event TokenSupported(
        address indexed token, MonadexV1Types.PriceFeedConfig indexed pythPriceFeedConfig
    );
    event TokenRemoved(address token);
    event RangeSizeChanged(uint256 indexed rangeSize);
    event PriceFeedIDUpdated(
        address indexed token, MonadexV1Types.PriceFeedConfig indexed priceFeedConfig
    );

    //////////////
    /// Errors ///
    //////////////

    error MonadexV1Raffle__NotRouter();
    error MonadexV1Raffle__InvalidConstructorArgs();
    error MonadexV1Raffle__RouterAddressAlreadyInitialised(address router);
    error MonadexV1Raffle__ZeroAmount();
    error MonadexV1Raffle__TokenNotSupported(address token);
    error MonadexV1Raffle__ZeroTickets();
    error MonadexV1Raffle__NotOpenForRegistration();
    error MonadexV1Raffle__NotEnoughTickets();
    error MonadexV1Raffle__NotEnoughBalance(uint256 ticketsToBurn, uint256 actualBalance);
    error MonadexV1Raffle__InsufficientFee();
    error MonadexV1Raffle__RandomNumberAlreadyRequested(uint64 sequenceNumber);
    error MonadexV1Raffle__DrawNotAllowedYet();
    error MonadexV1Raffle__CannotRequestRandomNumberYet();
    error MonadexV1Raffle__InsufficientEntries(
        uint256 numberOfParticipants, uint256 minimumParticipantsRequired
    );
    error MonadexV1Raffle__ZeroWinnings();
    error MonadexV1Raffle__TokenAlreadySupported(address token);
    error MonadexV1Raffle__CannotSupportMoreTokens();
    error MonadexV1Raffle__CannotRemoveTokenYet(address token, uint256 currentBalance);

    /////////////////
    /// Modifiers ///
    /////////////////

    modifier notZero(uint256 _value) {
        if (_value == 0) revert MonadexV1Raffle__ZeroAmount();
        _;
    }

    modifier onlyRouter(address _router) {
        if (_router != s_router) revert MonadexV1Raffle__NotRouter();
        _;
    }

    ///////////////////
    /// Constructor ///
    ///////////////////

    /// @notice Initializes the raffle state. Raffle begins as soon as this contract is deployed.
    /// @param _pythPriceFeedContract The pyth price feed contract address.
    /// @param _pricePerTicket The price
    /// @param _supportedTokens Tokens using which raffle tickets can be purchased.
    /// @param _priceFeedConfigs The token/USD price feed config associated with each supported token.
    /// @param _entropyContract The pyth entropy contract.
    /// @param _entropyProvider The pyth entropy provider contract.
    /// @param _winningPortions The portion each winner receives in each tier (index 0 -> tier 1,
    /// index 1 and 2 -> tier 2, index 3, 4, 5 -> tier 3).
    /// @param _minimumParticipants The minimum number of participant registration required before the
    /// draw can be made.
    constructor(
        address _pythPriceFeedContract,
        uint256 _pricePerTicket,
        address[] memory _supportedTokens,
        MonadexV1Types.PriceFeedConfig[] memory _priceFeedConfigs,
        address _entropyContract,
        address _entropyProvider,
        MonadexV1Types.Fraction[MAX_TIERS] memory _winningPortions,
        uint256 _minimumParticipants
    )
        MonadexV1RafflePriceCalculator(_pricePerTicket, _pythPriceFeedContract)
        MonadexV1RaffleEntropy(_entropyContract, _entropyProvider)
        ERC20("Monadex V1 Raffle Ticket", "MDXRT", 18)
        Ownable(msg.sender)
    {
        if (_supportedTokens.length != _priceFeedConfigs.length) {
            revert MonadexV1Raffle__InvalidConstructorArgs();
        }

        uint256 length = _supportedTokens.length;
        for (uint256 count = 0; count < length; ++count) {
            s_supportedTokens.push(_supportedTokens[count]);
            s_isSupportedToken[_supportedTokens[count]] = true;
            s_tokenToPriceFeedConfig[_supportedTokens[count]] = _priceFeedConfigs[count];
        }

        for (uint256 count = 0; count < MAX_TIERS; ++count) {
            s_winningPortions[count] = _winningPortions[count];
        }

        s_lastTimestamp = block.timestamp;
        s_minimumParticipants = _minimumParticipants;
    }

    //////////////////////////
    /// External Functions ///
    //////////////////////////

    /// @notice Since the router is deployed after the raffle, we need to set the router
    /// address in a separate transaction. This function can be called only once
    /// by the owner. The protocol team will set this value during deployment.
    /// @param _routerAddress The address of the router.
    function initializeRouterAddress(address _routerAddress) external onlyOwner {
        if (s_router != address(0)) {
            revert MonadexV1Raffle__RouterAddressAlreadyInitialised(s_router);
        }
        s_router = _routerAddress;

        emit RouterAddressSet(_routerAddress);
    }

    /// @notice Allows users to purchase raffle tickets for the given token amount. Purchasing
    /// tickets is only possible from the router during swaps. The router first transfers the token
    /// amount from the user, and then calls this function.
    /// @param _token The token used for the swap.
    /// @param _amount The amount of tokens to purchase raffle tickets with.
    /// @param _receiver The receiver of tickets.
    /// @return The amount of tickets purchased.
    function purchaseTickets(
        address _token,
        uint256 _amount,
        address _receiver
    )
        external
        onlyRouter(msg.sender)
        notZero(_amount)
        returns (uint256)
    {
        uint256 ticketsToMint = previewPurchase(_token, _amount);
        if (ticketsToMint == 0) revert MonadexV1Raffle__ZeroTickets();

        _mint(_receiver, ticketsToMint);

        emit TicketsPurchased(_token, _amount, _receiver, ticketsToMint);

        return ticketsToMint;
    }

    /// @notice After the raffle duration ends, a day long registration period will ensue.
    /// During this period, users can enter the raffle by burning their tickets. Raffle tickets
    /// are only burned in multiples of a fixed size (the range size, 1e18).
    /// So the actual amount of tickets burned may be less than or equal to the amount specified
    /// as the parameter. Users registering with more tickets will have a higher chance of winning
    /// their cut of each tier (it's possible to be the winner in more than one tier for a single user)
    /// because they will occupy a larger range on the number line.
    /// Users having a large number of tickets can split their amounts
    /// and register in separate transactions.
    /// Off-chain bots can be used to pay for gas and auto-register users as well.
    /// @param _user The user to register.
    /// @param _amount The amount of tickets to register with.
    /// @return The actual amount of tickets burned.
    function register(address _user, uint256 _amount) external notZero(_amount) returns (uint256) {
        if (!isRegistrationOpen() || s_currentSequenceNumber != 0) {
            revert MonadexV1Raffle__NotOpenForRegistration();
        }
        uint256 slotsToOccupy = _amount / RANGE_SIZE;
        if (slotsToOccupy == 0) revert MonadexV1Raffle__NotEnoughTickets();

        uint256 balance = balanceOf[_user];
        uint256 ticketsToBurn = slotsToOccupy * RANGE_SIZE;
        if (balance < ticketsToBurn) {
            revert MonadexV1Raffle__NotEnoughBalance(ticketsToBurn, balance);
        }

        uint256 currentRangeEnd = s_currentRangeEnd;
        for (uint256 count; count < slotsToOccupy; ++count) {
            s_ranges[currentRangeEnd] = _user;
            currentRangeEnd += RANGE_SIZE;
        }
        s_currentRangeEnd = currentRangeEnd;
        _burn(_user, ticketsToBurn);

        emit Registered(_user, ticketsToBurn);

        return ticketsToBurn;
    }

    /// @notice Requests a random number from Pyth entropy. A sequence number is returned
    /// which is stored for later verification of the received random number.
    /// This request can only be made after registration period ends.
    /// @param _userRandomNumber The user generated random number.
    function requestRandomNumber(bytes32 _userRandomNumber) external payable returns (uint64) {
        if (!hasRegistrationPeriodEnded()) {
            revert MonadexV1Raffle__CannotRequestRandomNumberYet();
        }
        uint256 numberOfParticipants = s_currentRangeEnd / RANGE_SIZE;
        if (numberOfParticipants < s_minimumParticipants) {
            revert MonadexV1Raffle__InsufficientEntries(numberOfParticipants, s_minimumParticipants);
        }

        uint256 fee = IEntropy(i_entropy).getFee(i_entropyProvider);
        if (msg.value < fee) {
            revert MonadexV1Raffle__InsufficientFee();
        }
        if (s_currentSequenceNumber != uint64(0)) {
            revert MonadexV1Raffle__RandomNumberAlreadyRequested(s_currentSequenceNumber);
        }
        uint64 sequenceNumber = IEntropy(i_entropy).requestWithCallback{ value: fee }(
            i_entropyProvider, _userRandomNumber
        );
        s_currentSequenceNumber = sequenceNumber;

        emit RandomNumberRequested(s_currentSequenceNumber);

        return sequenceNumber;
    }

    /// @notice Draws winners in different tiers and allocates rewards to them after the random
    /// number has been supplied.
    function drawWinnersAndAllocateRewards() external {
        if (!hasRegistrationPeriodEnded() || s_currentRandomNumber == 0) {
            revert MonadexV1Raffle__DrawNotAllowedYet();
        }

        address[MAX_WINNERS] memory winners;
        s_ranges[s_currentRangeEnd] = s_ranges[s_currentRangeEnd - RANGE_SIZE];

        winners = _selectWinners(uint256(s_currentRandomNumber));

        s_currentRangeEnd = 0;
        s_lastTimestamp = block.timestamp;
        s_currentSequenceNumber = 0;
        s_currentRandomNumber = 0;

        _allocateRewards(winners);

        emit WinnersPicked(winners);
    }

    /// @notice Allows winners of previous raffle draws to claim their winnings for supported tokens.
    /// Bots can be used to claim winnings on behalf of other users.
    /// @param _user The user whose winnings are to be claimed.
    /// @param _token The address of the token to claim winning amount from.
    /// @return The claimed winning amount.
    function claimWinnings(address _user, address _token) external returns (uint256) {
        if (!s_isSupportedToken[_token]) revert MonadexV1Raffle__TokenNotSupported(_token);
        uint256 winnings = s_winnings[_user][_token];
        if (winnings == 0) revert MonadexV1Raffle__ZeroWinnings();

        s_winnings[_user][_token] = 0;
        IERC20(_token).safeTransfer(_user, winnings);

        emit WinningsClaimed(_user, _token, winnings);

        return winnings;
    }

    /// @notice Support new tokens for raffle. Protocol team/governance must take care while
    /// supporting new tokens to ensure it doesn't have weird quirks or behaviour.
    /// @param _token The token to support.
    /// @param _pythPriceFeedConfig The token/USD price feed config.
    function supportToken(
        address _token,
        MonadexV1Types.PriceFeedConfig memory _pythPriceFeedConfig
    )
        external
        onlyOwner
    {
        if (s_isSupportedToken[_token]) revert MonadexV1Raffle__TokenAlreadySupported(_token);
        if (s_supportedTokens.length == MAX_SUPPORTED_TOKENS) {
            revert MonadexV1Raffle__CannotSupportMoreTokens();
        }

        s_isSupportedToken[_token] = true;
        s_supportedTokens.push(_token);
        s_tokenToPriceFeedConfig[_token] = _pythPriceFeedConfig;

        emit TokenSupported(_token, _pythPriceFeedConfig);
    }

    /// @notice Allows the protocol team (in early stages) or governance (later on) to remove support for a
    /// given token.
    /// @param _token The token to remove from raffle.
    function removeToken(address _token) external onlyOwner {
        if (!s_isSupportedToken[_token]) revert MonadexV1Raffle__TokenNotSupported(_token);
        uint256 balance = IERC20(_token).balanceOf(address(this));
        if (balance > 0) revert MonadexV1Raffle__CannotRemoveTokenYet(_token, balance);

        s_isSupportedToken[_token] = false;
        uint256 length = s_supportedTokens.length;
        for (uint256 count = 0; count < length; ++count) {
            if (s_supportedTokens[count] == _token) {
                s_supportedTokens[count] = s_supportedTokens[length - 1];
                break;
            }
        }
        s_supportedTokens.pop();
        s_tokenToPriceFeedConfig[_token] =
            MonadexV1Types.PriceFeedConfig({ priceFeedId: 0, noOlderThan: 0 });

        emit TokenRemoved(_token);
    }

    //////////////////////////
    /// Internal Functions ///
    //////////////////////////

    /// @notice Selects a random range based on the given random word and the current range end.
    /// @param _randomWord The random word obtained from Pyth entropy.
    /// @param _currentRangeEnd The current range end.
    /// @return The selected range.
    function _getSelectedRange(
        uint256 _randomWord,
        uint256 _currentRangeEnd
    )
        internal
        pure
        returns (uint256)
    {
        // Get the hitpoint. This point lies within a range.
        // For example, if the current range end is 600 with range size of 50.
        // the hitpoint may lie within any range, say 55, 89, etc.
        uint256 hitPoint = _randomWord % (_currentRangeEnd);
        // Adjust the hitpoint so that it points to the start of the range.
        // For example, if the hitpoint is 55, then it should point to 50 as the range start.
        // selectedRange = 55 - (55 % 50) = 50.
        uint256 selectedRange = hitPoint - (hitPoint % RANGE_SIZE);

        return selectedRange;
    }

    /// @notice A helper function that selects 6 winners in 3 tiers using a random word.
    /// @param _randomWord The random word obtained from Pyth entropy.
    /// @return An array of winners in different tiers.
    function _selectWinners(uint256 _randomWord) internal returns (address[MAX_WINNERS] memory) {
        address[MAX_WINNERS] memory winners;
        uint256 currentRangeEnd = s_currentRangeEnd;

        // After a winner has been picked, we swap out the winner with the last user on the number
        // line, and decrement the current range end by range size.
        for (uint256 count = 0; count < MAX_WINNERS; ++count) {
            uint256 selectedRange = _getSelectedRange(_randomWord, currentRangeEnd);
            winners[count] = s_ranges[selectedRange];
            s_ranges[selectedRange] = s_ranges[currentRangeEnd];
            currentRangeEnd -= RANGE_SIZE;
        }

        return winners;
    }

    /// @notice Allocates tokens as winnings to the raffle winners in different tiers.
    /// @param _winners The winners drawn.
    function _allocateRewards(address[MAX_WINNERS] memory _winners) internal {
        address[] memory supportedTokens = s_supportedTokens;
        uint256 numberOfSupportedTokens = supportedTokens.length;
        uint256[] memory tokenBalances = new uint256[](numberOfSupportedTokens);
        MonadexV1Types.Fraction[MAX_TIERS] memory winningPortions = s_winningPortions;
        MonadexV1Types.Fraction memory portion;

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

    ///////////////////////////////
    /// View and Pure Functions ///
    ///////////////////////////////

    /// @notice Gets the router's address.
    /// @return The router's address.
    function getRouterAddress() external view returns (address) {
        return s_router;
    }

    /// @notice Gets the UNIX timestamp when the last raffle began.
    /// @return The last UNIX timestamp.
    function getLastTimestamp() external view returns (uint256) {
        return s_lastTimestamp;
    }

    /// @notice Gets all the supported tokens packed into an array.
    /// @return An array of supported tokens.
    function getSupportedTokens() external view returns (address[] memory) {
        return s_supportedTokens;
    }

    /// @notice Checks if the specified token is supported or not.
    /// @param _token The token address to check.
    function isSupportedToken(address _token) external view returns (bool) {
        return s_isSupportedToken[_token];
    }

    /// @notice Gets the user at the start of a given range.
    /// @param _rangeStart The start of the range.
    function getUserAtRangeStart(uint256 _rangeStart) external view returns (address) {
        return s_ranges[_rangeStart];
    }

    /// @notice Gets the end of the current range.
    /// @return The current range's end.
    function getCurrentRangeEnd() external view returns (uint256) {
        return s_currentRangeEnd;
    }

    /// @notice Gets the winning portions in each tier.
    /// @return The winning portions in each tier.
    function getWinningPortions()
        external
        view
        returns (MonadexV1Types.Fraction[MAX_TIERS] memory)
    {
        return s_winningPortions;
    }

    /// @notice Gets the winnings of a given user for a given token.
    /// @param _user The user's address.
    /// @param _token The supported token.
    /// @return The user's winnings.
    function getWinnings(address _user, address _token) external view returns (uint256) {
        return s_winnings[_user][_token];
    }

    /// @notice Gets the raffle duration.
    /// @return The raffle duration in seconds.
    function getRaffleDuration() external pure returns (uint256) {
        return RAFFLE_DURATION;
    }

    /// @notice Gets the duration of the registration period.
    /// @return The registration period in seconds.
    function getRegistrationPeriod() external pure returns (uint256) {
        return REGISTRATION_PERIOD;
    }

    /// @notice Gets the maximum number of winners that can be drawn.
    /// @return The maximum number of raffle winners, combining all tiers.
    function getMaxWinners() external pure returns (uint256) {
        return MAX_WINNERS;
    }

    /// @notice Gets the maximum number of tiers in which winners are drawn.
    /// @return The maximum number of tiers.
    function getMaxTiers() external pure returns (uint256) {
        return MAX_TIERS;
    }

    /// @notice Gets the range size.
    /// @return The range size.
    function getRangeSize() external pure returns (uint256) {
        return RANGE_SIZE;
    }

    /// @notice Gets the minimum number of participants for a raffle.
    /// @return The minimum number of participants for a raffle draw.
    function getMinimumParticipantsForRaffle() external view returns (uint256) {
        return s_minimumParticipants;
    }

    /// @notice Gets the amount of tickets to mint based on the given token amount.
    /// @param _token The token used for purchasing tickets.
    /// @param _amount The token amount to use for ticket purchase.
    /// @return The number of tickets to purchase.
    function previewPurchase(address _token, uint256 _amount) public view returns (uint256) {
        return _getTicketsToMint(_token, _amount);
    }

    /// @notice Checks if the registration period is open.
    /// @return True if the registration period is open, false otherwise.
    function isRegistrationOpen() public view returns (bool) {
        if (block.timestamp < s_lastTimestamp + RAFFLE_DURATION) return false;
        else return true;
    }

    /// @notice Checks if the registration period has ended or not.
    /// @return True if registration period has ended, false otherwise.
    function hasRegistrationPeriodEnded() public view returns (bool) {
        if (block.timestamp < s_lastTimestamp + RAFFLE_DURATION + REGISTRATION_PERIOD) return false;
        else return true;
    }
}
