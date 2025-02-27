// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import { IEntropy } from "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import { IEntropyConsumer } from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import { IPyth } from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { ERC721 } from "@openzeppelin/token/ERC721/ERC721.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { PythStructs } from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import { PythUtils } from "@pythnetwork/pyth-sdk-solidity/PythUtils.sol";

import { IMonadexV1Raffle } from "@src/interfaces/IMonadexV1Raffle.sol";

import { MonadexV1Library } from "@src/library/MonadexV1Library.sol";
import { MonadexV1Types } from "@src/library/MonadexV1Types.sol";

/// @title MonadexV1Raffle.
/// @author Monadex Labs -- mgnfy-view.
/// @notice Raffle allows users to swap and pay additional fees on supported pools
/// to be eligible for the weekly draw.
contract MonadexV1Raffle is ERC721, Ownable, IEntropyConsumer, IMonadexV1Raffle {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    ///////////////////////
    /// State Variables ///
    ///////////////////////

    /// @dev The duration for which one raffle epoch lasts.
    uint256 private constant EPOCH_DURATION = 1 weeks;
    /// @dev The total number of tiers in which winners will be picked.
    uint8 private constant TIERS = 3;
    /// @dev The total number of winners to pick in tier 1.
    uint8 private constant WINNERS_IN_TIER_1 = 1;
    /// @dev The total number of winners to pick in tier 2.
    uint8 private constant WINNERS_IN_TIER_2 = 2;
    /// @dev The total number of winners to pick in tier 3.
    uint8 private constant WINNERS_IN_TIER_3 = 3;
    /// @dev Target decimals to represent the Pyth prices in.
    uint8 private constant TARGET_DECIMALS = 6;
    /// @dev Seed 1 for generating another random number from the source random number.
    string private constant SEED_1 = "Molandak";
    /// @dev Seed 2 for generating another random number from the source random number.
    string private constant SEED_2 = "Chog";
    /// @dev Seed 3 for generating another random number from the source random number.
    string private constant SEED_3 = "Moyaki";
    /// @dev Seed 4 for generating another random number from the source random number.
    string private constant SEED_4 = "Mon-Turtle";
    /// @dev The address of the `MonadexV1Router`.
    address private s_monadexV1Router;
    /// @dev This is the contract we query to get the price of each supported token in USD.
    address private immutable i_pyth;
    /// @dev Supported tokens for entering raffle. Pools with these tokens are indirectly supported
    /// for raffle.
    EnumerableSet.AddressSet private s_supportedTokens;
    /// @dev Each supported token has a corresponding token/USD price feed Id.
    mapping(address token => MonadexV1Types.PriceFeedConfig config) private s_tokenToPriceFeedConfig;
    /// @dev The Pyth contract which we'll use to request random numbers from.
    address private immutable i_entropy;
    /// @dev We can use different entropy providers to request random numbers from.
    address private immutable i_entropyProvider;
    /// @dev The current epoch. The first epoch is 1, not zero.
    uint256 private s_epoch;
    /// @dev The next Nft tokenId to mint as a receipt for raffle entry.
    uint256 private s_nextTokenId;
    /// @dev The timestamp when the last epoch ended.
    uint256 private s_lastDrawTimestamp;
    /// @dev The minimum number of Nfts to be minted in each epoch. This ensures that there are enough
    /// entries to select winners in all tiers.
    uint256 private s_minimumNftsToBeMintedEachEpoch;
    /// @dev Tracks the Nfts minted for a user in each epoch.
    mapping(address user => mapping(uint256 epoch => EnumerableSet.UintSet nfts)) private
        s_userNftsEachEpoch;
    /// @dev The total number of Nfts minted in each epoch.
    mapping(uint256 epoch => uint256 nftsMinted) private s_nftsMintedEachEpoch;
    /// @dev The range associated with each raffle Nft entry. The larger the range, the greater
    /// the chance of winning.
    mapping(uint256 tokenId => uint256[] range) private s_nftToRange;
    /// @dev The ending point of the last range for the epoch.
    mapping(uint256 epoch => uint256 endingPoint) private s_epochToEndingPoint;
    /// @dev The total token amounts collected in each epoch.
    mapping(uint256 epoch => mapping(address token => uint256 amount)) private
        s_epochToTokenAmountsCollected;
    /// @dev The random numbers supplied by Pyth in each epoch.
    mapping(uint256 epoch => uint256[] randomNumbers) private s_epochToRandomNumbers;
    /// @dev Tracks whether a user has claimed winnings from a tier in a given epoch. Prevents replays.
    mapping(
        uint256 tokenId
            => mapping(uint256 epoch => mapping(MonadexV1Types.Tiers tier => bool claimed))
    ) private s_hasUserClaimedEpochTierWinnings;
    /// @dev The winning portions of the total collected amount in each tier.
    /// For example, the winning portions may be like:
    /// 55% of total collected amount for 1 winner in tier 1.
    /// 15% of total collected amount for 2 winners in tier 2.
    /// 5% of total collected amount for 3 winners in tier 3.
    MonadexV1Types.Fraction[TIERS] private s_winningPortions;

    //////////////
    /// Events ///
    //////////////

    event MonadexV1RouterSet(address indexed monadexV1Router);
    event TokenSupported(
        address indexed _token, MonadexV1Types.PriceFeedConfig indexed priceFeedConfig
    );
    event TokenRemoved(address indexed token);
    event EnteredRaffle(
        address indexed receiver,
        address indexed tokenIn,
        uint256 amount,
        uint256 indexed nftTokenId,
        uint256 distance
    );
    event RandomNumberRequested();
    event TierWinningsClaimed(MonadexV1Types.RaffleClaim indexed claim);
    event EpochEnded(uint256 indexed epoch, bytes32 indexed randomNumber);
    event WinningPortionsSet(MonadexV1Types.Fraction[TIERS] indexed winningPortions);
    event MinimumNftsToBeMintedEachEpochSet(uint256 indexed minimumNftsToBeMintedEachEpoch);

    //////////////
    /// Errors ///
    //////////////

    error MonadexV1Raffle__NotRouter();
    error MonadexV1Raffle__RouterAlreadySet(address monadexV1Router);
    error MonadexV1Raffle__AddressZero();
    error MonadexV1Raffle__TokenAlreadySupported(address token);
    error MonadexV1Raffle__TokenNotSupported(address token);
    error MonadexV1Raffle__AmountZero();
    error MonadexV1Raffle__EpochHasNotEndedYet();
    error MonadexV1Raffle__InsufficientNftsMinted(
        uint256 nftsMinted, uint256 minimumNftsToBeMintedEachEpoch
    );
    error MonadexV1Raffle__InsufficientFeeForRequestingRandomNumber(
        uint256 feeGiven, uint256 expectedFee
    );
    error MonadexV1Raffle__RandomNumberAlreadyRequested();
    error MonadexV1Raffle__InvalidTier();
    error MonadexV1Raffle__AlreadyClaimedTierWinnings(uint256 tokenId, uint256 epoch, uint8 tier);
    error MonadexV1Raffle__InvalidWinningPortions();
    error MonadexV1Raffle__InvalidMinimumNumberOfNftsToBeMintedEachEpoch();

    modifier onlyMonadexV1Router() {
        if (msg.sender != s_monadexV1Router) {
            revert MonadexV1Raffle__NotRouter();
        }
        _;
    }

    ///////////////////
    /// Constructor ///
    ///////////////////

    /// @notice Sets the addresses for external services like Pyth, the `MonadexV1Router`,
    /// and some required params for raffle.
    /// @param _pyth The address of the Pyth contract to query prices from.
    /// @param _entropy The Pyth entropy contract to request random numbers from.
    /// @param _entropyProvider The entropy provider for requesting random numbers.
    /// @param _minimumNftsToBeMintedEachEpoch The minimum number of Nfts to be minted in each epoch.
    /// @param _winningPortions The winning portions for winners in each tier.
    constructor(
        address _pyth,
        address _entropy,
        address _entropyProvider,
        uint256 _minimumNftsToBeMintedEachEpoch,
        MonadexV1Types.Fraction[TIERS] memory _winningPortions
    )
        ERC721("Monadex V1 Raffle", "MDXR")
        Ownable(msg.sender)
    {
        if (_pyth == address(0) || _entropy == address(0) || _entropyProvider == address(0)) {
            revert MonadexV1Raffle__AddressZero();
        }

        _setMinimumNftsToBeMintedEachEpoch(_minimumNftsToBeMintedEachEpoch);
        _setWinningPortions(_winningPortions);

        i_pyth = _pyth;
        i_entropy = _entropy;
        i_entropyProvider = _entropyProvider;

        s_epoch = 1;
        s_lastDrawTimestamp = block.timestamp;
    }

    //////////////////////////
    /// External Functions ///
    //////////////////////////

    /// @notice Allows the owner to set the `MonadexV1Router` address once.
    /// @param _monadexV1Router The `MonadexV1Router` address.
    function initializeMonadexV1Router(address _monadexV1Router) external onlyOwner {
        if (s_monadexV1Router != address(0)) {
            revert MonadexV1Raffle__RouterAlreadySet(s_monadexV1Router);
        }

        s_monadexV1Router = _monadexV1Router;

        emit MonadexV1RouterSet(_monadexV1Router);
    }

    /// @notice Enables the owner to support tokens for raffle.
    /// @param _token The token address.
    /// @param _priceFeedConfig The Pyth price feed config.
    function supportToken(
        address _token,
        MonadexV1Types.PriceFeedConfig memory _priceFeedConfig
    )
        external
        onlyOwner
    {
        if (_token == address(0)) revert MonadexV1Raffle__AddressZero();
        if (s_supportedTokens.contains(_token)) {
            revert MonadexV1Raffle__TokenAlreadySupported(_token);
        }

        s_supportedTokens.add(_token);
        s_tokenToPriceFeedConfig[_token] = _priceFeedConfig;

        emit TokenSupported(_token, _priceFeedConfig);
    }

    /// @notice Allows the owner to revoke support from a token for raffle.
    /// @param _token The token address.
    function removeToken(address _token) external onlyOwner {
        if (_token == address(0)) revert MonadexV1Raffle__AddressZero();
        if (!s_supportedTokens.contains(_token)) revert MonadexV1Raffle__TokenNotSupported(_token);

        s_supportedTokens.remove(_token);
        delete s_tokenToPriceFeedConfig[_token];

        emit TokenRemoved(_token);
    }

    /// @notice Allows the owner to set winning portions for winners in each tier.
    /// @param _winningPortions The winning portions for winners in each tier.
    function setWinningPortions(
        MonadexV1Types.Fraction[TIERS] memory _winningPortions
    )
        external
        onlyOwner
    {
        _setWinningPortions(_winningPortions);
    }

    /// @notice Allows the owner to set the minimum number of Nfts to be minted in each epoch.
    /// @param _minimumNftsToBeMintedEachEpoch The minimum number of Nfts to be minted in each epoch.
    function setMinimumNftsToBeMintedEachEpoch(
        uint256 _minimumNftsToBeMintedEachEpoch
    )
        external
        onlyOwner
    {
        _setMinimumNftsToBeMintedEachEpoch(_minimumNftsToBeMintedEachEpoch);
    }

    /// @notice Allows users to enter the weekly raffle during a swap.
    /// @dev Only callable by the `MonadexV1Router`.
    /// @param _tokenIn The token used for entering raffle.
    /// @param _amount The amount of token to be used for entering raffle.
    /// @param _receiver The recipient of raffle Nft.
    /// @return The raffle Nft tokenId.
    function enterRaffle(
        address _tokenIn,
        uint256 _amount,
        address _receiver
    )
        external
        onlyMonadexV1Router
        returns (uint256)
    {
        if (_amount == 0) revert MonadexV1Raffle__AmountZero();
        if (_receiver == address(0)) revert MonadexV1Raffle__AddressZero();
        uint256 distance = _convertToUsd(_tokenIn, _amount);

        uint256 epoch = s_epoch;
        uint256 currentRangeEndingPoint = s_epochToEndingPoint[epoch];

        uint256 tokenId = ++s_nextTokenId;
        s_userNftsEachEpoch[_receiver][epoch].add(tokenId);
        s_nftsMintedEachEpoch[s_epoch]++;
        s_nftToRange[tokenId] = [currentRangeEndingPoint, currentRangeEndingPoint + distance];
        s_epochToEndingPoint[epoch] += distance;
        s_epochToTokenAmountsCollected[epoch][_tokenIn] += _amount;

        _safeMint(_receiver, tokenId);

        emit EnteredRaffle(_receiver, _tokenIn, _amount, tokenId, distance);

        return tokenId;
    }

    /// @notice Once the epoch has ended and the raffle has enough entries, anyone can request random
    /// numbers from Pyth to end the epoch.
    /// @param _userRandomNumber The seed random number supplied by the caller.
    function requestRandomNumber(bytes32 _userRandomNumber) external payable {
        uint256 epoch = s_epoch;

        if (block.timestamp - s_lastDrawTimestamp < EPOCH_DURATION) {
            revert MonadexV1Raffle__EpochHasNotEndedYet();
        }
        if (s_nftsMintedEachEpoch[epoch] < s_minimumNftsToBeMintedEachEpoch) {
            revert MonadexV1Raffle__InsufficientNftsMinted(
                s_nftsMintedEachEpoch[epoch], s_minimumNftsToBeMintedEachEpoch
            );
        }

        uint256 fee = IEntropy(i_entropy).getFee(i_entropyProvider);
        if (msg.value < fee) {
            revert MonadexV1Raffle__InsufficientFeeForRequestingRandomNumber(msg.value, fee);
        }
        IEntropy(i_entropy).requestWithCallback{ value: fee }(i_entropyProvider, _userRandomNumber);

        emit RandomNumberRequested();
    }

    /// @notice Allows anyone to claim the raffle tier winnings for a given epoch on behalf of valid winners.
    /// @param _claim The claim details.
    function claimTierWinnings(MonadexV1Types.RaffleClaim memory _claim) external {
        if (s_hasUserClaimedEpochTierWinnings[_claim.tokenId][_claim.epoch][_claim.tier]) {
            revert MonadexV1Raffle__AlreadyClaimedTierWinnings(
                _claim.tokenId, _claim.epoch, uint8(_claim.tier)
            );
        }
        s_hasUserClaimedEpochTierWinnings[_claim.tokenId][_claim.epoch][_claim.tier] = true;

        address owner = ownerOf(_claim.tokenId);
        MonadexV1Types.Winnings[] memory winnings = getWinnings(_claim);
        uint256 length = winnings.length;

        for (uint256 i; i < length; ++i) {
            if (winnings[i].amount > 0) {
                IERC20(winnings[i].token).safeTransfer(owner, winnings[i].amount);
            }
        }

        emit TierWinningsClaimed(_claim);
    }

    //////////////////////////
    /// Internal Functions ///
    //////////////////////////

    /// @notice Allows the owner to set winning portions for winners in each tier.
    /// @param _winningPortions The winning portions for winners in each tier.
    function _setWinningPortions(
        MonadexV1Types.Fraction[TIERS] memory _winningPortions
    )
        internal
        onlyOwner
    {
        if (
            _winningPortions.length > TIERS
                || _winningPortions[uint8(MonadexV1Types.Tiers.TIER1)].numerator == 0
                || _winningPortions[uint8(MonadexV1Types.Tiers.TIER2)].numerator == 0
                || _winningPortions[uint8(MonadexV1Types.Tiers.TIER3)].numerator == 0
                || _winningPortions[uint8(MonadexV1Types.Tiers.TIER1)].denominator == 0
                || _winningPortions[uint8(MonadexV1Types.Tiers.TIER1)].denominator
                    != _winningPortions[uint8(MonadexV1Types.Tiers.TIER2)].denominator
                || _winningPortions[uint8(MonadexV1Types.Tiers.TIER2)].denominator
                    != _winningPortions[uint8(MonadexV1Types.Tiers.TIER3)].denominator
                || _winningPortions[uint8(MonadexV1Types.Tiers.TIER1)].numerator
                    + _winningPortions[uint8(MonadexV1Types.Tiers.TIER2)].numerator * WINNERS_IN_TIER_2
                    + _winningPortions[uint8(MonadexV1Types.Tiers.TIER3)].numerator * WINNERS_IN_TIER_3
                    != _winningPortions[uint8(MonadexV1Types.Tiers.TIER1)].denominator
        ) revert MonadexV1Raffle__InvalidWinningPortions();

        for (uint256 i; i < TIERS; ++i) {
            s_winningPortions[i] = _winningPortions[i];
        }

        emit WinningPortionsSet(_winningPortions);
    }

    /// @notice Allows the owner to set the minimum number of Nfts to be minted in each epoch.
    /// @param _minimumNftsToBeMintedEachEpoch The minimum number of Nfts to be minted in each epoch.
    function _setMinimumNftsToBeMintedEachEpoch(uint256 _minimumNftsToBeMintedEachEpoch) internal {
        if (
            _minimumNftsToBeMintedEachEpoch
                <= WINNERS_IN_TIER_1 + WINNERS_IN_TIER_2 + WINNERS_IN_TIER_3
        ) revert MonadexV1Raffle__InvalidMinimumNumberOfNftsToBeMintedEachEpoch();

        s_minimumNftsToBeMintedEachEpoch = _minimumNftsToBeMintedEachEpoch;

        emit MinimumNftsToBeMintedEachEpochSet(_minimumNftsToBeMintedEachEpoch);
    }

    /// @notice Entropy callback by Pyth which supplies random number for a request.
    /// @param _randomNumber The supplied random number.
    function entropyCallback(uint64, address, bytes32 _randomNumber) internal override {
        s_epochToRandomNumbers[s_epoch].push(uint256(_randomNumber));
        s_epochToRandomNumbers[s_epoch].push(uint256(keccak256(abi.encode(_randomNumber))));
        s_epochToRandomNumbers[s_epoch].push(
            uint256(keccak256(abi.encode(_randomNumber, bytes(SEED_1))))
        );
        s_epochToRandomNumbers[s_epoch].push(
            uint256(keccak256(abi.encode(_randomNumber, bytes(SEED_2))))
        );
        s_epochToRandomNumbers[s_epoch].push(
            uint256(keccak256(abi.encode(_randomNumber, bytes(SEED_3))))
        );
        s_epochToRandomNumbers[s_epoch].push(
            uint256(keccak256(abi.encode(_randomNumber, bytes(SEED_4))))
        );
        uint256 epoch = s_epoch++;
        s_lastDrawTimestamp = block.timestamp;

        emit EpochEnded(epoch, _randomNumber);
    }

    ///////////////////////////////
    /// View and Pure Functions ///
    ///////////////////////////////

    /// @notice Converts the supplied token amount to usd in 18 decimals denomination.
    /// @param _token The token address.
    /// @param _amount The amount of token supplied.
    function _convertToUsd(address _token, uint256 _amount) internal view returns (uint256) {
        MonadexV1Types.PriceFeedConfig memory config = s_tokenToPriceFeedConfig[_token];
        PythStructs.Price memory price =
            IPyth(i_pyth).getPriceNoOlderThan(config.priceFeedId, config.noOlderThan);
        uint256 tokenDecimals = IERC20Metadata(_token).decimals();

        return MonadexV1Library.totalValueInUsd(_amount, price, TARGET_DECIMALS, tokenDecimals);
    }

    /// @notice Maps the tier to the slice of random numbers to determine winners in the tier.
    /// @param _tier The tier to draw winners in.
    /// @return The slice's starting index.
    /// @return The slice's ending index.
    function _mapTierToRandomNumbersArrayIndices(
        MonadexV1Types.Tiers _tier
    )
        internal
        pure
        returns (uint256, uint256)
    {
        if (_tier == MonadexV1Types.Tiers.TIER1) return (0, 1);
        else if (_tier == MonadexV1Types.Tiers.TIER2) return (1, 3);
        else return (3, 6);
    }

    /// @notice Gets the address of the Pyth entropy contract.
    /// @return The entropy contract's address.
    function getEntropy() internal view override returns (address) {
        return i_entropy;
    }

    /// @notice Gets the epoch duration for raffle.
    /// @return The epoch duration.
    function getEpochDuration() external pure returns (uint256) {
        return EPOCH_DURATION;
    }

    /// @notice Gets the total number of tiers for drawing raffle winners in.
    /// @return The total number of winners.
    function getTiers() external pure returns (uint256) {
        return TIERS;
    }

    /// @notice Gets the total number of winners to be selected in tier 1.
    /// @return The total number of winners to be selected in tier 1.
    function getWinnersInTier1() external pure returns (uint256) {
        return WINNERS_IN_TIER_1;
    }

    /// @notice Gets the total number of winners to be selected in tier 2.
    /// @return The total number of winners to be selected in tier 2.
    function getWinnersInTier2() external pure returns (uint256) {
        return WINNERS_IN_TIER_2;
    }

    /// @notice Gets the total number of winners to be selected in tier 3.
    /// @return The total number of winners to be selected in tier 3.
    function getWinnersInTier3() external pure returns (uint256) {
        return WINNERS_IN_TIER_3;
    }

    /// @notice Gets the address of the `MonadexV1Router`.
    /// @return The `MonadexV1Router` address.
    function getMonadexV1Router() external view returns (address) {
        return s_monadexV1Router;
    }

    /// @notice Gets the Pyth contract address for querying prices.
    /// @return The Pyth contract address.
    function getPyth() external view returns (address) {
        return i_pyth;
    }

    /// @notice Gets the Pyth entropy contract address.
    /// @return The Pyth entropy contract address.
    function getEntropyContract() external view returns (address) {
        return getEntropy();
    }

    /// @notice Gets the entropy provider address.
    /// @return The entropy provider address.
    function getEntropyProvider() external view returns (address) {
        return i_entropyProvider;
    }

    /// @notice Gets the supported tokens for raffle.
    /// @return The supported tokens for raffle.
    function getSupportedTokens() external view returns (address[] memory) {
        return s_supportedTokens.values();
    }

    /// @notice Gets the price feed config for a given token.
    /// @param _token The token address.
    function getTokenPriceFeedConfig(
        address _token
    )
        external
        view
        returns (MonadexV1Types.PriceFeedConfig memory)
    {
        return s_tokenToPriceFeedConfig[_token];
    }

    /// @notice Gets the current epoch number.
    /// @return The current epoch number.
    function getCurrentEpoch() external view returns (uint256) {
        return s_epoch;
    }

    /// @notice Gets the next raffle Nft tokenId to mint.
    /// @return The next raffle Nft tokenId to mint.
    function getNextTokenId() external view returns (uint256) {
        return s_nextTokenId;
    }

    /// @notice Gets the timestamp when the last epoch ended.
    /// @return The timestamp when the last epoch ended.
    function getLastDrawTimestamp() external view returns (uint256) {
        return s_lastDrawTimestamp;
    }

    /// @notice Gets the minimum number of Nfts to be minted for an epoch to end.
    /// @return The minimum number of Nfts to be minted for an epoch to end.
    function getMinimumNftsToBeMintedEachEpoch() external view returns (uint256) {
        return s_minimumNftsToBeMintedEachEpoch;
    }

    /// @notice Gets the user raffle Nfts minted each epoch.
    /// @param _user The user's address.
    /// @param _epoch The epoch number.
    /// @return An array of raffle tokenIds.
    function getUserNftsEachEpoch(
        address _user,
        uint256 _epoch
    )
        external
        view
        returns (uint256[] memory)
    {
        return s_userNftsEachEpoch[_user][_epoch].values();
    }

    /// @notice Gets the total number of raffl Nfts minted for a given epoch.
    /// @param _epoch The epoch number.
    /// @return The total number of raffl Nfts minted for a given epoch.
    function getNftsMintedEachEpoch(uint256 _epoch) external view returns (uint256) {
        return s_nftsMintedEachEpoch[_epoch];
    }

    /// @notice Gets the range occupied by a raffle Nft in an epoch.
    /// @param _tokenId The raffle Nft tokenId.
    /// @return The range occupied by the Nft tokenId.
    function getNftToRange(uint256 _tokenId) external view returns (uint256[] memory) {
        return s_nftToRange[_tokenId];
    }

    /// @notice Gets the epoch range ending point.
    /// @param _epoch The epoch number.
    /// @return The range ending point for a given epoch.
    function getEpochToRangeEndingPoint(uint256 _epoch) external view returns (uint256) {
        return s_epochToEndingPoint[_epoch];
    }

    /// @notice Gets the total amount of a given token collected in an epoch.
    /// @param _epoch The epoch number.
    /// @param _token The token address.
    /// @return The total token amount collected in an epoch.
    function getTokenAmountCollectedInEpoch(
        uint256 _epoch,
        address _token
    )
        external
        view
        returns (uint256)
    {
        return s_epochToTokenAmountsCollected[_epoch][_token];
    }

    /// @notice Gets the random numbers supplied by Pyth entropy for a given epoch.
    /// @param _epoch The epoch number.
    /// @return An array of random numbers.
    function getEpochToRandomNumbersSupplied(
        uint256 _epoch
    )
        external
        view
        returns (uint256[] memory)
    {
        return s_epochToRandomNumbers[_epoch];
    }

    /// @notice Checks if a user has claimed winnings from a tier in a given epoch.
    /// @param _tokenId The user's raffle Nft tokenId.
    /// @param _epoch The epoch number.
    /// @param _tier The raffle tier.
    function hasUserClaimedTierWinningsForEpoch(
        uint256 _tokenId,
        uint256 _epoch,
        MonadexV1Types.Tiers _tier
    )
        external
        view
        returns (bool)
    {
        return s_hasUserClaimedEpochTierWinnings[_tokenId][_epoch][_tier];
    }

    /// @notice Checks if a token is supported for raffle.
    /// @param _token The token address.
    /// @return A bool indicating whether a token is supported or not.
    function isSupportedToken(address _token) external view returns (bool) {
        return s_supportedTokens.contains(_token);
    }

    /// @notice Gets the time remaining until the next epoch.
    /// @return The time remaining until the next epoch.
    function getTimeRemainingUntilNextEpoch() external view returns (uint256) {
        return EPOCH_DURATION - (block.timestamp - s_lastDrawTimestamp);
    }

    /// @notice Gets the winning amounts for a user for an epoch.
    /// @param _claim The claim details.
    /// @return The winning amounts for an epoch.
    function getWinnings(
        MonadexV1Types.RaffleClaim memory _claim
    )
        public
        view
        returns (MonadexV1Types.Winnings[] memory)
    {
        MonadexV1Types.Winnings[] memory winnings;

        if (_claim.tier < MonadexV1Types.Tiers.TIER1 || _claim.tier > MonadexV1Types.Tiers.TIER3) {
            revert MonadexV1Raffle__InvalidTier();
        }
        if (_claim.epoch == 0 || _claim.tokenId == 0) revert MonadexV1Raffle__AmountZero();

        uint256 epochRangeEndingPoint = s_epochToEndingPoint[_claim.epoch];
        uint256[] memory nftToRange = s_nftToRange[_claim.tokenId];
        uint256[] memory epochToRandomNumbers = s_epochToRandomNumbers[_claim.epoch];

        address[] memory tokens = s_supportedTokens.values();
        uint256 length = tokens.length;
        winnings = new MonadexV1Types.Winnings[](length);
        uint256[] memory tokenBalances = new uint256[](length);

        for (uint256 i; i < length; ++i) {
            tokenBalances[i] = s_epochToTokenAmountsCollected[_claim.epoch][tokens[i]];
            winnings[i].token = tokens[i];
        }

        if (s_hasUserClaimedEpochTierWinnings[_claim.tokenId][_claim.epoch][_claim.tier]) {
            return (winnings);
        }

        (uint256 start, uint256 end) = _mapTierToRandomNumbersArrayIndices(_claim.tier);
        MonadexV1Types.Fraction memory winningPortion =
            s_winningPortions[uint8(MonadexV1Types.Tiers.TIER3)];

        for (uint256 i = start; i < end; ++i) {
            uint256 hitPoint = epochToRandomNumbers[i] % epochRangeEndingPoint;
            if (hitPoint >= nftToRange[0] && hitPoint < nftToRange[1]) {
                for (uint256 j; j < length; ++j) {
                    uint256 tokenBalance = tokenBalances[j];
                    uint256 winningAmount =
                        (tokenBalance * winningPortion.numerator) / winningPortion.denominator;
                    if (winningAmount > 0) winnings[j].amount += winningAmount;
                }
            }
        }

        return (winnings);
    }
}
