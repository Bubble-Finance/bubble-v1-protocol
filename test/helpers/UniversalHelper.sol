// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { MonadexV1Factory } from "../../src/core/MonadexV1Factory.sol";
import { Token } from "../utils/Token.sol";
import { Test } from "forge-std/Test.sol";

contract UniversalHelper is Test {
    address public protocolTeamMultisig;
    uint256 public constant PROTOCOL_FEE = 99995;
    uint256 public constant POOL_FEE = 99700;
    MonadexV1Factory public factory;
    Token public tokenA;
    Token public tokenB;
    address public deployer;
    address public user1;
    address public user2;

    modifier distributeTokens(uint256 _tokenAAmount, uint256 _tokenBAmount) {
        vm.startPrank(deployer);
        tokenA.mint(deployer, _tokenAAmount);
        tokenA.mint(user1, _tokenAAmount);
        tokenA.mint(user2, _tokenAAmount);

        tokenB.mint(deployer, _tokenBAmount);
        tokenB.mint(user1, _tokenBAmount);
        tokenB.mint(user2, _tokenBAmount);
        vm.stopPrank();
        _;
    }

    function setUp() public {
        deployer = makeAddr("Monadex Labs");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        protocolTeamMultisig = deployer;

        vm.startPrank(deployer);
        tokenA = new Token("TokenA", "A");
        tokenB = new Token("TokenB", "B");
        factory = new MonadexV1Factory(protocolTeamMultisig, PROTOCOL_FEE, POOL_FEE);
        factory.setToken(address(tokenA), true);
        factory.setToken(address(tokenB), true);
        vm.stopPrank();

        vm.label(address(factory), "MonadexV1Factory");
        vm.label(address(tokenA), "tokenA");
        vm.label(address(tokenB), "tokenB");
        vm.label(deployer, "deployer");
        vm.label(user1, "user1");
        vm.label(user2, "user2");
    }
}
