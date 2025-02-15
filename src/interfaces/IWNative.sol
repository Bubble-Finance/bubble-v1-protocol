//SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IWNative {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function balanceOf(address) external view returns (uint256);

    function allowance(address, address) external view returns (uint256);

    receive() external payable;

    function deposit() external payable;

    function withdraw(uint256 _amount) external;

    function totalSupply() external view returns (uint256);

    function approve(address _to, uint256 _amount) external returns (bool);

    function transfer(address _to, uint256 _amount) external returns (bool);

    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool);
}
