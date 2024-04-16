// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IMonadexV1Factory {
    function deployPool(address _tokenA, address _tokenB) external returns (address);
    function setProtocolTeamMultisigAddress(address _protocolTeamMultisig) external;
    function setToken(address _token, bool _isSupported) external;
    function getProtocolTeamMultisigAddress() external view returns (address);
    function getProtocolFee() external view returns (uint256, uint256);
    function getPoolFee() external view returns (uint256, uint256);
    function isSupportedToken(address _token) external view returns (bool);
    function getTokenPairToPool(address _tokenA, address _tokenB) external view returns (address);
}
