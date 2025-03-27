// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BubbleV1Types } from "@src/library/BubbleV1Types.sol";

interface IBubbleV1Router {
    function addLiquidity(
        BubbleV1Types.AddLiquidity memory _addLiquidityParams
    )
        external
        returns (uint256, uint256, uint256);

    function addLiquidityNative(
        BubbleV1Types.AddLiquidityNative memory _addLiquidityNativeParams
    )
        external
        payable
        returns (uint256, uint256, uint256);

    function removeLiquidityWithPermit(
        BubbleV1Types.RemoveLiquidityWithPermit memory _params
    )
        external
        returns (uint256, uint256);

    function removeLiquidityNativeWithPermit(
        BubbleV1Types.RemoveLiquidityNativeWithPermit memory _params
    )
        external
        returns (uint256, uint256);

    function removeLiquidityNativeSupportingFeeOnTransferTokens(
        address _token,
        uint256 _lpTokensToBurn,
        uint256 _amountTokenMin,
        uint256 _amountNativeMin,
        address _receiver,
        uint256 _deadline
    )
        external
        returns (uint256);

    function removeLiquidityNativeWithPermitSupportingFeeOnTransferTokens(
        address _token,
        uint256 _lpTokensToBurn,
        uint256 _amountTokenMin,
        uint256 _amountNativeMin,
        address _receiver,
        uint256 _deadline,
        bool _approveMax,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        external
        returns (uint256);

    function swapExactTokensForTokens(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path,
        address _receiver,
        uint256 _deadline,
        BubbleV1Types.Raffle memory _raffle
    )
        external
        returns (uint256[] memory, uint256);

    function swapTokensForExactTokens(
        uint256 _amountOut,
        uint256 _amountInMax,
        address[] calldata _path,
        address _receiver,
        uint256 _deadline,
        BubbleV1Types.Raffle memory _raffle
    )
        external
        returns (uint256[] memory, uint256);

    function swapExactNativeForTokens(
        uint256 _amountOutMin,
        address[] calldata _path,
        address _receiver,
        uint256 _deadline,
        BubbleV1Types.Raffle memory _raffle
    )
        external
        payable
        returns (uint256[] memory, uint256);

    function swapTokensForExactNative(
        uint256 _amountOut,
        uint256 _amountInMax,
        address[] calldata _path,
        address _receiver,
        uint256 _deadline,
        BubbleV1Types.Raffle memory _enter
    )
        external
        returns (uint256[] memory, uint256);

    function swapExactTokensForNative(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path,
        address _receiver,
        uint256 _deadline,
        BubbleV1Types.Raffle memory _raffle
    )
        external
        returns (uint256[] memory, uint256);

    function swapNativeForExactTokens(
        uint256 _amountOut,
        address[] calldata _path,
        address _receiver,
        uint256 _deadline,
        BubbleV1Types.Raffle memory _raffle
    )
        external
        payable
        returns (uint256[] memory, uint256);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path,
        address _receiver,
        uint256 _deadline,
        BubbleV1Types.Raffle memory _raffle
    )
        external;

    function swapExactNativeForTokensSupportingFeeOnTransferTokens(
        uint256 _amountOutMin,
        address[] calldata _path,
        address _receiver,
        uint256 _deadline,
        BubbleV1Types.Raffle memory _raffle
    )
        external
        payable;

    function swapExactTokensForNativeSupportingFeeOnTransferTokens(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path,
        address _receiver,
        uint256 _deadline,
        BubbleV1Types.Raffle memory _raffle
    )
        external;

    function removeLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _lpTokensToBurn,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _receiver,
        uint256 _deadline
    )
        external
        returns (uint256, uint256);

    function removeLiquidityNative(
        address _token,
        uint256 _lpTokensToBurn,
        uint256 _amountTokenMin,
        uint256 _amountNativeMin,
        address _receiver,
        uint256 _deadline
    )
        external
        returns (uint256, uint256);

    function getFactory() external view returns (address);

    function getRaffle() external view returns (address);

    function getWNative() external view returns (address);

    function quote(
        uint256 _amountA,
        uint256 _reserveA,
        uint256 _reserveB
    )
        external
        pure
        returns (uint256);

    function getAmountOut(
        uint256 _amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut,
        BubbleV1Types.Fraction memory _poolFee
    )
        external
        pure
        returns (uint256);

    function getAmountIn(
        uint256 _amountOut,
        uint256 _reserveIn,
        uint256 _reserveOut,
        BubbleV1Types.Fraction memory _poolFee
    )
        external
        pure
        returns (uint256);

    function getAmountsOut(
        uint256 _amountIn,
        address[] calldata _path
    )
        external
        view
        returns (uint256[] memory);

    function getAmountsIn(
        uint256 _amountOut,
        address[] calldata _path
    )
        external
        view
        returns (uint256[] memory);
}
