## AUDIT 1
## TITLE: Wrong check placement in the `claimTierWinnings` function

## Description:
in the `claimTierWinnings` function, the is a mapping that set that a user has claimed, this setter is coming before the `getWinnings` function is being called, in the `getWinnings` function, there is a check that set the winning struct to zero,i assume this serves as a check to make sure claimed user does get an reward by claiming again, i think this isn't necessary since there is a ``MonadexV1Raffle__AlreadyClaimedTierWinnings` error check in the `claimTierWinnings` function. that's a subjective opinion, doesn't change much.
## Mitigation:
```diff
function claimTierWinnings(MonadexV1Types.RaffleClaim memory _claim) external {
        if (s_hasClaimedEpochTierWinnings[_claim.tokenId][_claim.epoch][_claim.tier]) {
            revert MonadexV1Raffle__AlreadyClaimedTierWinnings(
                _claim.tokenId, _claim.epoch, uint8(_claim.tier)
            );
        }
-         s_hasClaimedEpochTierWinnings[_claim.tokenId][_claim.epoch][_claim.tier] = true;

        address owner = ownerOf(_claim.tokenId);
        MonadexV1Types.Winnings[] memory winnings = getWinnings(_claim);
        uint256 length = winnings.length;

        for (uint256 i; i < length; ++i) {
            if (winnings[i].amount > 0) {
                IERC20(winnings[i].token).safeTransfer(owner, winnings[i].amount);
            }
        }
        // @audit next line should be used here
+        s_hasClaimedEpochTierWinnings[_claim.tokenId][_claim.epoch][_claim.tier] = true;

        emit TierWinningsClaimed(_claim);
    }

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

-        if (s_hasClaimedEpochTierWinnings[_claim.tokenId][_claim.epoch][_claim.tier]) {
-            return (winnings);
-        }

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
```

## AUDIT 2

## TITLE:  `_claim.tier` should be used instead of Hardcoding `TIER3` when updating the `s_winningPortions` mapping in the `getWinnings` function

## DESCRIPTION: 
not fully comprenehding the intended action here, but i assume it is a mistake using the  `TIER3` while updating the `s_winningPortions` mapping, by doing this, if a user want to claim tier 1 reward they will be receiving tier3 reward and portion. 

## MITIGATION:
```diff 
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

        if (s_hasClaimedEpochTierWinnings[_claim.tokenId][_claim.epoch][_claim.tier]) {
            return (winnings);
        }

        (uint256 start, uint256 end) = _mapTierToRandomNumbersArrayIndices(_claim.tier);
        MonadexV1Types.Fraction memory winningPortion =
-            s_winningPortions[uint8(MonadexV1Types.Tiers.TIER3)];
+            s_winningPortions[uint8(_claim.tier)];

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
```