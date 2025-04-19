// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./ReentrancyAttacker.sol";
import { Test, console } from "forge-std/Test.sol";

import { BubbleV1Factory } from "@src/core/BubbleV1Factory.sol";
import { BubbleV1Pool } from "@src/core/BubbleV1Pool.sol";

contract BubblePoolReentrancyTest is Test {
    BubbleV1Factory factory;
    BubbleV1Pool pool;
    ReentrancyAttacker attacker;

    address tokenA;
    address tokenB;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public {
        // Deploy factory with test parameters
        factory = new BubbleV1Factory(
            address(this), // protocolTeamMultisig
            BubbleV1Types.Fraction(1, 100), // 1% protocol fee
            [
                BubbleV1Types.Fraction(1, 1000), // Tier 1: 0.1%
                BubbleV1Types.Fraction(2, 1000), // Tier 1: 0.2%
                BubbleV1Types.Fraction(3, 1000), // Tier 2: 0.3%
                BubbleV1Types.Fraction(4, 1000), // Tier 1: 0.4%
                BubbleV1Types.Fraction(5, 1000) // Tier 3: 0.5%
            ]
        );

        // Create test ERC20 tokens
        tokenA = address(new MockERC20("TokenA", "TA"));
        tokenB = WETH; // Using WETH as second token

        // Deploy pool
        factory.deployPool(tokenA, tokenB);
        pool = BubbleV1Pool(factory.getTokenPairToPool(tokenA, tokenB));

        // Deploy attacker
        attacker = new ReentrancyAttacker(address(pool), 5); // Max 5 reentrancy depths

        // Fund the pool
        uint256 initialLiquidity = 100 ether;
        deal(tokenA, address(pool), initialLiquidity);
        deal(tokenB, address(pool), initialLiquidity);

        // Initialize reserves
        pool.syncReservesBasedOnBalances();
    }

    function test_PoolSwapReentrancy() public {
        // Verify initial reserves
        (uint256 reserveA, uint256 reserveB) = pool.getReserves();
        assertEq(reserveA, 100 ether);
        assertEq(reserveB, 100 ether);

        // Start attack - requesting 10% of reserves
        uint256 attackAmount = 10 ether;
        attacker.startAttack(attackAmount);

        // Verify reserves were drained
        (uint256 newReserveA, uint256 newReserveB) = pool.getReserves();
        assertLt(newReserveA, reserveA - attackAmount);
        assertLt(newReserveB, reserveB - attackAmount);

        console.log("Initial reserves: A:%s B:%s", reserveA, reserveB);
        console.log("Post-attack reserves: A:%s B:%s", newReserveA, newReserveB);
        console.log("Attack successful - reserves drained beyond expected amount");
    }
}

contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    mapping(address => uint256) public balanceOf;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}
