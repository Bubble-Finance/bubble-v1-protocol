// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { MonadexV1Types } from "../library/MonadexV1Types.sol";

interface IMonadexV1Pool {
    function setProtocolTeamMultisig(address _protocolTeamMultisig) external;
    function setProtocolFee(MonadexV1Types.Fee memory _fee) external;
}
