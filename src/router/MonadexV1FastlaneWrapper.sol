// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.25;

// import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

// import { DAppControl } from "@atlas/dapp/DAppControl.sol";
// import { CallConfig } from "@atlas/types/ConfigTypes.sol";

// import { SolverOperation } from "@atlas/types/SolverOperation.sol";
// import { UserOperation } from "@atlas/types/UserOperation.sol";

// import { IMonadexV1Router } from "../interfaces/IMonadexV1Router.sol";
// import { MonadexV1Types } from "../library/MonadexV1Types.sol";

// struct SwapTokenInfo {
//     address inputToken;
//     uint256 inputAmount;
//     address outputToken;
//     uint256 outputMin;
// }

// contract MonadexDAppControl is DAppControl {
//     address public constant MONADEX_ROUTER = 0x89831AED10991214D3Bd417FF0E97E5e876bE8dD;
//     uint256 public constant PERCENTAGE_DENOMINATOR = 10_000; //basis points denominator
//     uint32 public constant SOLVER_GAS_LIMIT = 5_000_000;
//     address internal constant _ETH = address(0); // address of the ETH token

//     uint256 public govPercent;
//     uint256 public minBidThreshold;
//     address public bidToken;
//     address public govPayoutAddr;

//     // Add a new event to log bid token changes
//     event BidTokenAddressUpdated(address indexed oldBidToken, address indexed newBidToken);
//     event GovernancePayoutAddressUpdated(
//         address indexed oldGovPayoutAddr, address indexed newGovPayoutAddr
//     );
//     event GovernancePayoutSplitUpdated(uint256 oldPercentage, uint256 newPercentage);
//     event MinBidThresholdUpdated(address bidToken, uint256 minBidThreshold);

//     // allocate value hook events
//     event UserPayout(address indexed user, uint256 amount);
//     event GovernancePayout(address indexed govPayoutAddr, uint256 amount);

//     error BidBelowMinimumThreshold();
//     error InsufficientOutputBalance();
//     error InsufficientUserOpValue();
//     error InvalidRewardAddress();
//     error InvalidUserOpData();
//     error OnlyGovernance();
//     error SameBidToken();
//     error UnsupportedFunctionSelector();
//     error UserOpDappNotSwapRouter();

//     /**
//      * @notice Constructor for BaseSwapDAppControl
//      *     @param _atlas The address of the Atlas contract
//      *     @param _bidToken The address of the bid token (address(0) for ETH)
//      *     @param _govPayoutAddr The address of the governance payout address
//      *     @param _govPercent The percentage of the bid amount that goes to the governance payout address
//      *     @param _minBidThreshold The minimum bid threshold for a solver to be eligible for payout
//      */
//     constructor(
//         address _atlas,
//         address _bidToken,
//         address _govPayoutAddr,
//         uint256 _govPercent,
//         uint256 _minBidThreshold
//     )
//         DAppControl(
//             _atlas,
//             msg.sender,
//             CallConfig({
//                 userNoncesSequential: false,
//                 dappNoncesSequential: false,
//                 requirePreOps: true,
//                 trackPreOpsReturnData: true,
//                 trackUserReturnData: false,
//                 delegateUser: false,
//                 requirePreSolver: false,
//                 requirePostSolver: false,
//                 requirePostOps: true,
//                 zeroSolvers: true,
//                 reuseUserOp: true,
//                 userAuctioneer: false,
//                 solverAuctioneer: false,
//                 unknownAuctioneer: false,
//                 verifyCallChainHash: true,
//                 forwardReturnData: true,
//                 requireFulfillment: false,
//                 trustedOpHash: true,
//                 invertBidValue: false,
//                 exPostBids: true, // NOTE: allow solver to set bidAmount after onchain bid-finding
//                 allowAllocateValueFailure: false
//             })
//         )
//     {
//         // Set bidToken to constant ETH if zero address
//         bidToken = _bidToken == _ETH ? _ETH : _bidToken;
//         minBidThreshold = _minBidThreshold;
//         govPayoutAddr = _govPayoutAddr;

//         // Initialize governance percentage
//         require(_govPercent <= PERCENTAGE_DENOMINATOR, "Governance percentage cannot exceed 100%");
//         govPercent = _govPercent;
//     }

//     // ---------------------------------------------------- //
//     //                     DAPP SETTERS                     //
//     // ---------------------------------------------------- //

//     /**
//      * @notice Sets the reward address for the contract
//      * @param _govPayoutAddr The new reward address
//      * @dev This function can only be called by the governance
//      * @dev The zero address (address(0)) is not allowed as a reward address
//      */
//     function setGovPayoutAddr(address _govPayoutAddr) external onlyGovernance {
//         require(_govPayoutAddr != govPayoutAddr, "Governance payout address is already set");
//         require(_govPayoutAddr != address(0), "Governance address cannot be zero");
//         emit GovernancePayoutAddressUpdated(govPayoutAddr, _govPayoutAddr);
//         govPayoutAddr = _govPayoutAddr;
//     }

//     /**
//      * @notice This function is called by the owner to set the bidToken
//      * @param _bidToken The address of the bid token
//      * @dev This function is only callable by the owner
//      * @dev The zero address (address(0)) is interpreted as ETH
//      */
//     function setBidToken(address _bidToken) external onlyGovernance {
//         if (_bidToken == bidToken) revert SameBidToken();
//         emit BidTokenAddressUpdated(bidToken, _bidToken);
//         bidToken = _bidToken;
//     }

//     /**
//      * @notice Updates the governance percentage for bidAmount split
//      * @param _govPercent The new governance percentage in basis points (0-10000)
//      * @dev This function can only be called by the governance
//      * @dev The governance percentage cannot exceed 100% (10000 basis points)
//      */
//     function setGovPercent(uint256 _govPercent) external onlyGovernance {
//         require(_govPercent <= PERCENTAGE_DENOMINATOR, "Governance percentage cannot exceed 100%");
//         require(_govPercent != govPercent, "New percentage must be different");

//         emit GovernancePayoutSplitUpdated(govPercent, _govPercent);
//         govPercent = _govPercent;
//     }

//     /**
//      * @notice Sets the minimum bid threshold for a solver to be considered for solving
//      * @param _minBidThreshold The minimum bid threshold for a solver to be eligible for payout
//      * @dev This function can only be called by the governance
//      * @dev minBidThreshold will be used during postSolverCall to check if the solver bid is below the threshold
//      */
//     function setMinBidThreshold(uint256 _minBidThreshold) external onlyGovernance {
//         minBidThreshold = _minBidThreshold;
//         emit MinBidThresholdUpdated(bidToken, _minBidThreshold);
//     }

//     // ---------------------------------------------------- //
//     //                     ATLAS HOOKS                      //
//     // ---------------------------------------------------- //

//     function _preOpsCall(
//         UserOperation calldata userOp
//     )
//         internal
//         virtual
//         override
//         returns (bytes memory)
//     {
//         if (userOp.dapp != MONADEX_ROUTER) revert UserOpDappNotSwapRouter();

//         (bool success, bytes memory swapData) = CONTROL.staticcall(
//             abi.encodeWithSelector(this.decodeUserOpData.selector, userOp.data, userOp.value)
//         );

//         if (!success) revert InvalidUserOpData();

//         SwapTokenInfo memory _swapInfo = abi.decode(swapData, (SwapTokenInfo));

//         // If inputToken is ERC20, transfer tokens from user to EE, and approve router for swap
//         if (userOp.value < _swapInfo.inputAmount) {
//             if (_swapInfo.inputToken != _ETH) {
//                 _transferUserERC20(_swapInfo.inputToken, address(this), _swapInfo.inputAmount);
//                 SafeTransferLib.safeApprove(
//                     _swapInfo.inputToken, userOp.dapp, _swapInfo.inputAmount
//                 );
//             } else {
//                 revert InsufficientUserOpValue();
//             }
//         }

//         return swapData; // return SwapTokenInfo in bytes format, to be used in allocateValue.
//     }

//     function _allocateValueCall(
//         address _bidToken,
//         uint256 bidAmount,
//         bytes calldata data
//     )
//         internal
//         virtual
//         override
//     {
//         {
//             // Check if the solver bid is below the minimum threshold simulated mode only
//             if (_simulation()) {
//                 (bool _success, bytes memory _minThresholdData) =
//                     CONTROL.staticcall(abi.encodeWithSelector(this.minBidThreshold.selector));
//                 uint256 _minBidThreshold = abi.decode(_minThresholdData, (uint256));
//                 if (!_success || bidAmount < _minBidThreshold) revert BidBelowMinimumThreshold();
//             }
//         }

//         // Decode the swap info from the data
//         SwapTokenInfo memory _swapInfo = abi.decode(data, (SwapTokenInfo));

//         // Transfer bid token to governance payout address
//         (bool success, bytes memory _payoutData) =
//             CONTROL.staticcall(abi.encodeWithSelector(this.getPayoutData.selector));

//         if (!success || data.length == 0) revert InvalidRewardAddress();
//         (address _govPayoutAddr, uint256 _govPercent) = abi.decode(_payoutData, (address, uint256));

//         // Calculate governance and user amounts and split the bidAmount
//         uint256 govPayoutAmount = (bidAmount * _govPercent) / PERCENTAGE_DENOMINATOR;
//         uint256 userAmount = bidAmount - govPayoutAmount;

//         // Transfer governance amount to payout address if not zero
//         if (govPayoutAmount > 0) {
//             if (_bidToken == _ETH) {
//                 SafeTransferLib.safeTransferETH(_govPayoutAddr, govPayoutAmount);
//             } else {
//                 SafeTransferLib.safeTransfer(_bidToken, _govPayoutAddr, govPayoutAmount);
//             }
//             emit GovernancePayout(_govPayoutAddr, govPayoutAmount);
//         }

//         //Transfer user amount to user if not zero skip if bidToken overlaps with InputToken or OutputToken
//         if (
//             userAmount > 0 && _swapInfo.outputToken != _bidToken
//                 && _swapInfo.inputToken != _bidToken
//         ) {
//             if (_bidToken == _ETH) {
//                 SafeTransferLib.safeTransferETH(_user(), userAmount);
//             } else {
//                 SafeTransferLib.safeTransfer(_bidToken, _user(), userAmount);
//             }
//             emit UserPayout(_user(), userAmount);
//         }

//         // Note: Whenever bidToken overlaps with InputToken or OutputToken, the bidAmount should be excluded from the
//         // refund calculations.
//         uint256 _outputTokenBalance = _balanceOf(_swapInfo.outputToken);
//         uint256 _inputTokenBalance = _balanceOf(_swapInfo.inputToken);

//         if (_outputTokenBalance < _swapInfo.outputMin) revert InsufficientOutputBalance();

//         _transferUserTokens(_swapInfo, _outputTokenBalance, _inputTokenBalance);
//     }

//     function _postOpsCall(bool solved, bytes calldata data) internal virtual override {
//         if (solved) return; // token distribution already handled in allocateValue hook

//         SwapTokenInfo memory _swapInfo = abi.decode(data, (SwapTokenInfo));
//         uint256 _outputTokenBalance = _balanceOf(_swapInfo.outputToken);
//         uint256 _inputTokenBalance = _balanceOf(_swapInfo.inputToken);

//         if (_outputTokenBalance < _swapInfo.outputMin) revert InsufficientOutputBalance();

//         _transferUserTokens(_swapInfo, _outputTokenBalance, _inputTokenBalance);
//     }

//     // ---------------------------------------------------- //
//     //                 GETTERS AND HELPERS                  //
//     // ---------------------------------------------------- //

//     function getBidFormat(UserOperation calldata) public view virtual override returns (address) {
//         return bidToken;
//     }

//     function getBidValue(
//         SolverOperation calldata solverOp
//     )
//         public
//         view
//         virtual
//         override
//         returns (uint256)
//     {
//         return solverOp.bidAmount;
//     }

//     function getSolverGasLimit() public view virtual override returns (uint32) {
//         return SOLVER_GAS_LIMIT;
//     }

//     function getPayoutData() public view returns (address, uint256) {
//         return (govPayoutAddr, govPercent);
//     }

//     function _transferUserTokens(
//         SwapTokenInfo memory swapInfo,
//         uint256 outputTokenBalance,
//         uint256 inputTokenBalance
//     )
//         internal
//     {
//         // Transfer output token to user
//         if (swapInfo.outputToken == _ETH) {
//             SafeTransferLib.safeTransferETH(_user(), outputTokenBalance);
//         } else {
//             SafeTransferLib.safeTransfer(swapInfo.outputToken, _user(), outputTokenBalance);
//         }

//         // If any leftover input token, transfer back to user
//         if (inputTokenBalance > 0) {
//             if (swapInfo.inputToken == _ETH) {
//                 SafeTransferLib.safeTransferETH(_user(), inputTokenBalance);
//             } else {
//                 SafeTransferLib.safeTransfer(swapInfo.inputToken, _user(), inputTokenBalance);
//             }
//         }
//     }

//     /**
//      * @notice Decodes the user operation data for BaseSwap swaps
//      * @param userData The calldata of the user operation
//      * @return swapTokenInfo Struct containing details about the swap
//      * @dev This function decodes the user operation data and extracts relevant swap information
//      * @dev It supports three types of swaps: ETH to Token, Token to ETH, and Token to Token
//      * @dev Reverts if an unsupported function selector is provided
//      */
//     function decodeUserOpData(
//         bytes calldata userData,
//         uint256 userValue
//     )
//         public
//         pure
//         returns (SwapTokenInfo memory swapTokenInfo)
//     {
//         bytes4 funcSelector = bytes4(userData);
//         bytes memory decodeData = userData[4:];

//         if (funcSelector == IMonadexV1Router.swapExactTokensForTokens.selector) {
//             (uint256 amountIn, uint256 amountOutMin, address[] memory path,,,) = abi.decode(
//                 decodeData,
//                 (uint256, uint256, address[], address, uint256, MonadexV1Types.PurchaseTickets)
//             );
//             swapTokenInfo.inputToken = path[0];
//             swapTokenInfo.outputToken = path[path.length - 1];
//             swapTokenInfo.inputAmount = amountIn;
//             swapTokenInfo.outputMin = amountOutMin;
//         } else if (funcSelector == IMonadexV1Router.swapTokensForExactTokens.selector) {
//             (uint256 amountOut, uint256 amountInMax, address[] memory path,,,) = abi.decode(
//                 decodeData,
//                 (uint256, uint256, address[], address, uint256, MonadexV1Types.PurchaseTickets)
//             );
//             swapTokenInfo.inputToken = path[0];
//             swapTokenInfo.outputToken = path[path.length - 1];
//             swapTokenInfo.inputAmount = amountInMax;
//             swapTokenInfo.outputMin = amountOut;
//         } else if (funcSelector == IMonadexV1Router.swapExactNativeForTokens.selector) {
//             (uint256 amountOutMin, address[] memory path,,,) = abi.decode(
//                 decodeData, (uint256, address[], address, uint256, MonadexV1Types.PurchaseTickets)
//             );
//             swapTokenInfo.inputToken = _ETH;
//             swapTokenInfo.outputToken = path[path.length - 1];
//             swapTokenInfo.inputAmount = userValue;
//             swapTokenInfo.outputMin = amountOutMin;
//         } else if (funcSelector == IMonadexV1Router.swapTokensForExactNative.selector) {
//             (uint256 amountOut, uint256 amountInMax, address[] memory path,,,) = abi.decode(
//                 decodeData,
//                 (uint256, uint256, address[], address, uint256, MonadexV1Types.PurchaseTickets)
//             );
//             swapTokenInfo.inputToken = path[0];
//             swapTokenInfo.outputToken = _ETH;
//             swapTokenInfo.inputAmount = amountInMax;
//             swapTokenInfo.outputMin = amountOut;
//         } else if (funcSelector == IMonadexV1Router.swapExactTokensForNative.selector) {
//             (uint256 amountIn, uint256 amountOutMin, address[] memory path,,,) = abi.decode(
//                 decodeData,
//                 (uint256, uint256, address[], address, uint256, MonadexV1Types.PurchaseTickets)
//             );
//             swapTokenInfo.inputToken = path[0];
//             swapTokenInfo.outputToken = _ETH;
//             swapTokenInfo.inputAmount = amountIn;
//             swapTokenInfo.outputMin = amountOutMin;
//         } else if (funcSelector == IMonadexV1Router.swapNativeForExactTokens.selector) {
//             (uint256 amountOut, address[] memory path,,,) = abi.decode(
//                 decodeData, (uint256, address[], address, uint256, MonadexV1Types.PurchaseTickets)
//             );
//             swapTokenInfo.inputToken = _ETH;
//             swapTokenInfo.outputToken = path[path.length - 1];
//             swapTokenInfo.inputAmount = userValue;
//             swapTokenInfo.outputMin = amountOut;
//         } else {
//             revert UnsupportedFunctionSelector();
//         }
//     }

//     function _balanceOf(address token) internal view returns (uint256) {
//         if (token == _ETH) {
//             return address(this).balance;
//         } else {
//             return SafeTransferLib.balanceOf(token, address(this));
//         }
//     }

//     // ---------------------------------------------------- //
//     //                    Modifiers                         //
//     // ---------------------------------------------------- //

//     modifier onlyGovernance() {
//         address _dAppGov = MonadexDAppControl(this).getDAppSignatory();
//         if (msg.sender != _dAppGov) revert OnlyGovernance();
//         _;
//     }
// }

// // contract MonadexV1FastlaneWrapper is DAppControl {
// //     address private immutable i_monadexV1Router;
// // }
