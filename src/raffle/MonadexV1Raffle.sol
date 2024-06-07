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

import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { IMonadexV1Raffle } from "../interfaces/IMonadexV1Raffle.sol";
import { IEntropy } from "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import { IEntropyConsumer } from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import { IPyth } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

import { MonadexV1Library } from "../library/MonadexV1Library.sol";
import { MonadexV1Types } from "../library/MonadexV1Types.sol";
import { MonadexV1RafflePriceCalculator } from "./MonadexV1RafflePriceCalculator.sol";

/**
 * @title MonadexV1Raffle.
 * @author Monadex Labs -- mgnfy-view.
 * @notice The raffle contract allows users to purchase tickets during swaps from the router,
 * enter the weekly draw by burning their tickets, and have a chance at winning from a large
 * prize pool. This contract will be deployed separately, and then the ownership will be trnasferred
 * to the router.
 */
contract MonadexV1Raffle is
    IMonadexV1Raffle,
    IEntropyConsumer,
    MonadexV1RafflePriceCalculator,
    ERC20,
    Ownable
{
    using SafeERC20 for IERC20;

    ///////////////////////
    /// State Variables ///
    ///////////////////////

    // The duration for which the raffle will continue
    // Any registrations won't be accepted during this period
    uint256 private constant RAFFLE_DURATION = 1 weeks - 1 days;
    // The registration period begins right after the raffle duration
    // During this period, users can register themselves for the weekly draw
    uint256 private constant REGISTRATION_PERIOD = 1 days;
    // The maximum number of winners to draw for the raffle
    uint256 private constant MAX_WINNERS = 6;
    // Tiers are layers in which winners will be drawn
    uint256 private constant MAX_TIERS = 3;
    // One winner is drawn in tier 1 and receives a large prize amount
    uint256 private constant WINNERS_IN_TIER1 = 1;
    // 2 winners are drawn in the second tier, and both of them receive an equal prize amount
    // which is lesser than the amount given to tier 1 winner, but greater than the amount
    // given to tier 3 winners
    uint256 private constant WINNERS_IN_TIER2 = 2;
    // 3 winners from tier 3 receive equal prize amount each, but lesser than the prize amount
    // given to tier 2 winners
    uint256 private constant WINNERS_IN_TIER3 = 3;
    // The maximum number of multipliers available to be applied during ticket purchase
    uint256 private constant MAX_MULTIPLIERS = 3;
    // We use ranges of a fixed size to register users for a draw
    // Imagine a number line extending in both directions with fixed size intervals of 50
    // We begin at 0
    // If you have 100 tickets, you will be put in  ranges, 0-50 and 50-100
    // If you occupy large number of ranges, you have more chances of winning
    // A random number is selected and can pick users on any random range
    // You increase your chances of being picked if you occupy a large range
    // The range size is given by: 10 ** token decimals (by default 18)
    uint256 private constant RANGE_SIZE = 1e18;
    // We need to store the router's address to ensure that purchases are made from the router
    // only
    address private s_router;
    // Stores the UNIX timestamp of the time when the last draw was made
    uint256 private s_lastTimestamp;
    // Users will only be able to purchase tickets if they conduct swaps
    // on pools with supported tokens
    // The amounts of these tokens are collected in the raffle contract
    // and then given out to winners in tiers
    // Once a token is supported, support cannot be revoked
    address[] private s_supportedTokens;
    mapping(address token => bool isSupported) private s_isSupportedToken;
    // Tracks ranges which are occupied by users
    // For example, range[0] = address("Bob")
    // range[50e18] = address("Bob")
    // range[100e18] = address("Alice")
    // Here, Bob occupies ranges 0-50e18 and 50e18-100e18
    // Alice occupies range 100e18-150e18
    mapping(uint256 rangeStart => address user) private s_ranges;
    uint256 private s_currentRangeEnd;
    // Each multiplier is associated with a percentage
    // Applying a multiplier on an amount is the portion of that amount which
    // will be used for purchasing tickets
    // The larger the multiplier, the more tickets you get
    // We stick to 3 multipliers, and the percentages associated with each cannot
    // be changed after deployment
    // For example, if you apply multiplier 2 with an associated percentage of 2% on amount 10_000
    // The amount of 200 will be used to purchase tickets
    MonadexV1Types.Fee[MAX_MULTIPLIERS] private s_multipliersToPercentages;
    // The percentage of the total amount that the winner gets for a given tier
    // This applies for all supported tokens
    // For example, winner in tier 1 gets 55% of amounts collected in token A, token B, ... and so on
    // 2 winners in tier 2 both get 15% of amounts collected in token A, token B, ... and so on
    // 3 winners in tier 3 both get 5% of amounts collected in token A, token B, ... and so on
    // 45% + (2 * 20%) + (3 * 5%) = 100%
    MonadexV1Types.Fee[MAX_TIERS] private s_winningPortions;
    // We use the pull or over push pattern
    // Users can pull their raffle winnings for a given supported token
    mapping(address user => mapping(address token => uint256 amount)) private s_winnings;
    // With pyth entropy you need to store both the entropy and entropy provider to be used for requests
    IEntropy private immutable i_entropy;
    address private immutable i_entropyProvider;
    uint64 private s_currentSequenceNumber;

    //////////////
    /// Events ///
    //////////////

    event RouterAddressSet(address router);
    event TicketsPurchased(address indexed receiver, uint256 indexed amount);
    event Registered(address indexed user, uint256 indexed ticketsBurned);
    event DrawRequested(uint64 sequenceNumber);
    event WinnersPicked(address[MAX_WINNERS] indexed winners);
    event WinningsClaimed(
        address indexed winner, address indexed token, uint256 amount, address indexed receiver
    );
    event TokenSupported(address indexed token, bytes32 indexed pythPriceFeedID);
    event RangeSizeChanged(uint256 indexed rangeSize);
    event PriceFeedIDUpdated(address indexed token, bytes32 indexed priceFeedD);

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
    error MonadexV1Raffle__NotEnoughBalance();
    error MonadexV1Raffle__InsufficientFee();
    error MonadexV1Raffle__DrawNotAllowedYet();
    error MonadexV1Raffle__InsufficientEntries();
    error MonadexV1Raffle__ZeroWinnings();
    error MonadexV1Raffle__TokenAlreadySupported();
    error MonadexV1Raffle__SequenceNumbersDoNotMatch();

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

    /**
     * @notice Initializes the raffle state. Raffle begins as soon as this contract is deployed.
     * @param _supportedTokens Tokens using which raffle tickets can be purchased.
     * @param _priceFeedIds The token/USD price feed Id associated with each supported token.
     * @param _multipliersToPercentages The percentages associated with multipliers.
     * @param _winningPortions The portion each winner receives in each tier (index 0 -> tier 1,
     * index 1 and 2 -> tier 2, index 3, 4, 5 -> tier 3).
     * @param _pythPriceFeedContract The pyth price feed contract address.
     * @param _entropy The pyth entropy contract.
     * @param _entropyProvider The pyth entropy provider contract.
     */
    constructor(
        address[] memory _supportedTokens,
        bytes32[] memory _priceFeedIds,
        MonadexV1Types.Fee[MAX_MULTIPLIERS] memory _multipliersToPercentages,
        MonadexV1Types.Fee[MAX_TIERS] memory _winningPortions,
        address _pythPriceFeedContract,
        address _entropy,
        address _entropyProvider
    )
        MonadexV1RafflePriceCalculator(_pythPriceFeedContract)
        ERC20("MonadexV1RaffleTicket", "MDXRT")
        Ownable(msg.sender)
    {
        if (_supportedTokens.length != _priceFeedIds.length) {
            revert MonadexV1Raffle__InvalidConstructorArgs();
        }

        s_lastTimestamp = block.timestamp;

        for (uint256 count = 0; count < MAX_MULTIPLIERS; ++count) {
            s_multipliersToPercentages[count] = _multipliersToPercentages[count];
        }

        uint256 length = _supportedTokens.length;
        for (uint256 count = 0; count < length; ++count) {
            s_supportedTokens.push(_supportedTokens[count]);
            s_isSupportedToken[_supportedTokens[count]] = true;
            s_tokenToPriceFeedId[_supportedTokens[count]] = _priceFeedIds[count];
        }

        for (uint256 count = 0; count < MAX_TIERS; ++count) {
            s_winningPortions[count] = _winningPortions[count];
        }

        i_entropy = IEntropy(_entropy);
        i_entropyProvider = _entropyProvider;
    }

    //////////////////////////
    /// External Functions ///
    //////////////////////////

    /**
     * @notice Since the router is deployed after the raffle, we need to set the router
     * address in a separate instead of the constructor. This function can be called only
     * once by the owner. (The protocol team will set this value during deployment, and
     * later, the ownership will be transferred to governance).
     * @param _routerAddress The address of the router.
     */
    function initializeRouterAddress(address _routerAddress) external onlyOwner {
        if (s_router != address(0)) {
            revert MonadexV1Raffle__RouterAddressAlreadyInitialised(s_router);
        }
        s_router = _routerAddress;

        emit RouterAddressSet(_routerAddress);
    }

    /**
     * @notice Allows users to purchase raffle tickets for the given token amount. Purchasing
     * tickets is only possible from the router during swaps. Tickets should be purchasable
     * at a constant price.
     * @param _token The token which was swapped for another token.
     * @param _amount The amount of token that was used for swapping.
     * @param _multiplier The multiplier to apply to the ticket purchase.
     * @param _receiver The receiver of tickets.
     * @return The amount of tickets purchased.
     */
    function purchaseTickets(
        address _token,
        uint256 _amount,
        MonadexV1Types.Multipliers _multiplier,
        address _receiver
    )
        external
        onlyRouter(msg.sender)
        notZero(_amount)
        returns (uint256)
    {
        if (!s_isSupportedToken[_token]) revert MonadexV1Raffle__TokenNotSupported(_token);
        uint256 ticketsToMint = previewPurchase(_token, _amount, _multiplier);
        if (ticketsToMint == 0) revert MonadexV1Raffle__ZeroTickets();
        _mint(_receiver, ticketsToMint);

        emit TicketsPurchased(_receiver, ticketsToMint);

        return ticketsToMint;
    }

    /**
     * @notice After the raffle duration ends, a day long registration period will ensue.
     * During this period, users can enter the raffle by burning their tickets. Raffle tickets
     * are only burned in multiples of a fixed size (the range size, 1e18).
     * So the actual amount of tickets burned may be less than or equal to the amount specified
     * as the parameter. Users registering with more tickets will have a higher chance of winning
     * their cut of each tier (it's possible to be the winner in more than one tier for a single user)
     * because they will occupy a larger range on the number line.
     * @param _amount The amount of tickets to register with.
     * @return The actual amount of tickets burned.
     */
    function register(uint256 _amount) external notZero(_amount) returns (uint256) {
        if (!isRegistrationOpen()) revert MonadexV1Raffle__NotOpenForRegistration();
        uint256 slotsToOccupy = _amount / RANGE_SIZE;
        if (slotsToOccupy == 0) revert MonadexV1Raffle__NotEnoughTickets();

        uint256 balance = balanceOf(msg.sender);
        uint256 ticketsToBurn = slotsToOccupy * RANGE_SIZE;
        if (ticketsToBurn < balance) revert MonadexV1Raffle__NotEnoughBalance();

        uint256 currentRangeEnd = s_currentRangeEnd;
        for (uint256 count = 0; count < slotsToOccupy; ++count) {
            s_ranges[currentRangeEnd] = msg.sender;
            currentRangeEnd += RANGE_SIZE;
        }
        s_currentRangeEnd = currentRangeEnd;
        _burn(msg.sender, ticketsToBurn);

        emit Registered(msg.sender, ticketsToBurn);

        return ticketsToBurn;
    }

    /**
     * @notice Selects 6 winners in 3 tiers after the registration period ends, and increases each
     * winner's winnings so that they can claim it whenever they like.
     * @param _userRandomNumber The user generated random number.
     */
    function drawWinners(bytes32 _userRandomNumber) external payable {
        if (block.timestamp < s_lastTimestamp + RAFFLE_DURATION + REGISTRATION_PERIOD) {
            revert MonadexV1Raffle__DrawNotAllowedYet();
        }
        if (s_currentRangeEnd - RANGE_SIZE < MAX_WINNERS * RANGE_SIZE) {
            revert MonadexV1Raffle__InsufficientEntries();
        }

        uint256 fee = i_entropy.getFee(i_entropyProvider);
        if (msg.value < fee) {
            revert MonadexV1Raffle__InsufficientFee();
        }
        s_currentSequenceNumber =
            i_entropy.requestWithCallback{ value: fee }(i_entropyProvider, _userRandomNumber);

        emit DrawRequested(s_currentSequenceNumber);
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
     * @notice Support new tokens for raffle. Once token is supported, it cannot be removed.
     * This is to avoid potential issues. Protocol team/governance must take care while
     * supporting new tokens.
     * @param _token The token to support.
     * @param _pythPriceFeedId The _token/USD price feed Id.
     */
    function supportToken(address _token, bytes32 _pythPriceFeedId) external onlyOwner {
        if (s_isSupportedToken[_token]) revert MonadexV1Raffle__TokenAlreadySupported();

        s_isSupportedToken[_token] = true;
        s_supportedTokens.push(_token);
        s_tokenToPriceFeedId[_token] = _pythPriceFeedId;

        emit TokenSupported(_token, _pythPriceFeedId);
    }

    /**
     * @notice Gets the router address.
     * @return The router's address.
     */
    function getRouterAddress() external view returns (address) {
        return s_router;
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
     * @notice Gets the winnings of a given user for a given token.
     * @param _user The user's address.
     * @param _token The supported token.
     * @return The user's winnings.
     */
    function getWinnings(address _user, address _token) external view returns (uint256) {
        return s_winnings[_user][_token];
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
     * @notice Gets the range size.
     * @return The range size.
     */
    function getRangeSize() external pure returns (uint256) {
        return RANGE_SIZE;
    }

    ////////////////////////
    /// Public Functions ///
    ////////////////////////

    /**
     * @notice Gets the percentage of fee taken for each multiplier.
     * @param _multiplier The multiplier.
     * @return A fee struct, with numerator and denominator fields.
     */
    function getMultiplierToPercentage(MonadexV1Types.Multipliers _multiplier)
        public
        view
        returns (MonadexV1Types.Fee memory)
    {
        if (_multiplier == MonadexV1Types.Multipliers.Multiplier1) {
            return s_multipliersToPercentages[0];
        } else if (_multiplier == MonadexV1Types.Multipliers.Multiplier2) {
            return s_multipliersToPercentages[1];
        } else {
            return s_multipliersToPercentages[2];
        }
    }

    /**
     * @notice Gets the amount of tickets to mint based on the given amount and multiplier.
     * @param _token The token used for purchasing tickets.
     * @param _amount The token amount to use for ticket purchase.
     * @param _multiplier The multiplier to apply to the token amount.
     * @return The number of tickets to purchase.
     */
    function previewPurchase(
        address _token,
        uint256 _amount,
        MonadexV1Types.Multipliers _multiplier
    )
        public
        view
        returns (uint256)
    {
        uint256 amountAfterMultiplierApplied = MonadexV1Library
            .calculateAmountAfterApplyingPercentage(_amount, getMultiplierToPercentage(_multiplier));

        return _getTicketsToMint(_token, amountAfterMultiplierApplied);
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
     * @notice Gets the address of the entropy contract which will call the callback.
     * @return The entropy contract address.
     */
    function getEntropy() internal view override returns (address) {
        return address(i_entropy);
    }

    /**
     * @notice Once a random number is received, this function is called by pyth and winners
     * are picked.
     * @param _sequenceNumber The number associated with each request.
     * @param _randomNumber The supplied random number.
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
            revert MonadexV1Raffle__SequenceNumbersDoNotMatch();
        }

        address[MAX_WINNERS] memory winners;
        s_ranges[s_currentRangeEnd] = s_ranges[s_currentRangeEnd - RANGE_SIZE];

        winners = _selectWinners(uint256(_randomNumber));

        s_currentRangeEnd = 0;
        s_lastTimestamp = block.timestamp;

        _allocateRewards(winners);

        emit WinnersPicked(winners);
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
        pure
        returns (uint256)
    {
        // get the hitpoint. This point lies within a range
        // for example, if the current range end is 600 with range size of 50
        // the hitpoint may lie within any range, say 55, or 89, etc
        uint256 hitPoint = _randomWord % (_currentRangeEnd);
        // convert the hitpoint so that it points to the start of the range
        // for example, if the hitpoint is 55, then it should point to 50 as the range start
        // selectedRange = 55 - (55 % 50) = 50
        uint256 selectedRange = hitPoint - (hitPoint % RANGE_SIZE);

        return selectedRange;
    }

    /**
     * @notice A helper function that selects 6 winners using a random word.
     * @param _randomWord The random word obtained from a VRF service.
     * @return An array of winners.
     */
    function _selectWinners(uint256 _randomWord) internal returns (address[6] memory) {
        address[MAX_WINNERS] memory winners;
        uint256 currentRangeEnd = s_currentRangeEnd;
        uint256 rangeSize = RANGE_SIZE;

        // after a winner has been picked, we swap out the winner with the last user on the number
        // line and decrement the currentRangeEnd by rangeSize
        for (uint256 count = 0; count < MAX_WINNERS; ++count) {
            uint256 selectedRange = _getSelectedRange(_randomWord, currentRangeEnd);
            winners[count] = s_ranges[selectedRange];
            s_ranges[selectedRange] = s_ranges[currentRangeEnd];
            if (count != 5) currentRangeEnd -= rangeSize;
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
        uint256[] memory tokenBalances = new uint256[](numberOfSupportedTokens);
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
