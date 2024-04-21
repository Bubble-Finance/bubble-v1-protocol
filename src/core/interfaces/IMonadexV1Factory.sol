// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { MonadexV1Types } from "../library/MonadexV1Types.sol";

interface IMonadexV1Factory {
    function getProtocolTeamMultisig() external view returns (address);
    function getProtocolFee() external view returns (MonadexV1Types.Fee memory);
    function getTokenPairToFee(
        address _tokenA,
        address _tokenB
    )
        external
        view
        returns (MonadexV1Types.Fee memory);
}
