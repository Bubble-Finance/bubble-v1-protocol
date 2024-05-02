// SPDX-License-Identifier: MIT
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

/// @title MonadexV1Raffle
/// @author Ola Hamid
/// @notice ....
/// @notice

pragma solidity ^0.8.20;

import { IERC20 } from "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { MonadexRandomGenerator } from "../raffle/MonadexRandomGenerator.sol";
// import {IMonadexRandomGenerator} from ".././raffle/IMonadexRandomGenerator.sol";
import { Ownable } from "../../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { SafeERC20 } from
    "../../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "../../../lib/openzeppelin-contracts/contracts/utils/Address.sol";

// import { MonadexTicket } from "../raffle/MonadexTicket.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract MonadexV1Raffle is Ownable, ERC20 {
    using SafeERC20 for IERC20;
    using Address for address;
    /////////////////////
    ///state variables///
    /////////////////////

    // IERC20 internal s_monad; //eth sapolia will be representing monad for now
    MonadexRandomGenerator internal numberGenerator; // for genersating numbers

    // uint256 internal s_requestID; //reqest ID for random number generator
    uint256 public startingTimestamp;
    uint256 public closingTimestamp;
    status public s_status;
    uint256 public costPer;
    uint256 public raffleID;
    address[] public holders;
    address[] public BuyTokens;

    ///////////
    ///ERROR///
    //////////
    error Monadex_TicketIDNotCorrect();
    error Monadex_needMoreThanZero();
    error Monadex_zeroAddress();
    error Monad_InsufficientFund();
    error Monadex_InvalidRaffleState();
    error MTicket_untransferable();

    ///////////
    ///ENUM///
    //////////
    enum status {
        unstated, //notstated, the lottery has not stated yet
        open, //open, the lottery is open
        closed //the raffle is closed for any more ticket
    }
    enum multiplier {
        Multiplier1, // 1
        Multiplier2, // 2
        Multiplier3 // 4

    }

    ///////////////////
    ///struct & MAPS///
    ///////////////////
    // struct raffleInformation {
    //     // uint256 raffleID;
    //     status raffleStatus;
    //     uint256 AmountForTotalWinners;
    //     uint256 costPerTicket;
    // }
    // struct TicketInfo {
    //     uint256 ticketID;
    //     address buyer;
    // }

    // mapping(address => raffleInformation) internal m_raffleInfoStorage;
    mapping(uint256 => mapping(multiplier => address)) internal m_multiplierBuyerStorage;
    mapping(uint256 => address) public m_Rafflers;

    /////////////////
    ///constructor///
    ////////////////
    constructor( address _IRandomGenerator, uint256 _costPer) Ownable(msg.sender) ERC20("MonadexTicket","MDXT" ) {
        if ( _IRandomGenerator == address(0)) {
            revert Monadex_zeroAddress();
        }
        numberGenerator = MonadexRandomGenerator(_IRandomGenerator);
        costPer = _costPer;
    }

    ///////////////////
    ///set Functions///
    ///////////////////

    function mint(address to, uint amount) public {
        _mint(to, amount);
    }

    function burn(address from, uint amount) public {
        _burn(from, amount);
    }
    /**
     * @dev non transferable ticket tokens to not allow users send transfer out tickets
     
     */
    function transferFrom(address /*from*/, address /*to*/, uint256 /*value*/) public pure override returns (bool) {
        revert MTicket_untransferable();
    }

    function transfer(address /*recipient*/, uint256 /*amount*/) public pure override returns (bool) {
        revert MTicket_untransferable();
    }


    function addBuyTokens(address[] memory tokenAddr) public onlyOwner{
        for (uint tokenIndex = 0; tokenIndex < tokenAddr.length; ++tokenIndex){
            BuyTokens.push(tokenAddr[tokenIndex]);
        }
    }

    function initialise(uint256 TimeDuration /* awwek ~ 604,800*/ ) public onlyOwner {
        s_status = status.open;
        startingTimestamp = block.timestamp;
        if (closingTimestamp == startingTimestamp + TimeDuration) {
            burnAllTicket();
            raffleID++;
        }
    }

    function buyTicket(address _tokenAddr,multiplier Multiplier, uint256 /*noOfTicket*/, address _receiver ) public payable {
        uint256 totalCost = calculateTotalCostInTicket(Multiplier);
        //check for lesser value in the user wallet, this could be removed if it contradict the payable keyword
        if (msg.value >= totalCost) {
            revert Monad_InsufficientFund();
        }
        if (msg.sender == address(0)) {
            revert Monadex_zeroAddress();
        }
        if (s_status != status.open) {
            revert Monadex_InvalidRaffleState();
        }
        IERC20(_tokenAddr).safeTransferFrom(_receiver, address(this), totalCost);
        mint(_receiver, totalCost);
        m_multiplierBuyerStorage[totalCost][Multiplier] = _receiver;
        m_Rafflers[holders.length] = _receiver;
        holders.push(_receiver);
    }

    function calculateTotalCostInTicket(
        multiplier Multiplier /*,
        uint256 noOfTicket*/
    )
        internal
        view
        returns (uint256)
    {
        uint256 multiplierValue;
        //set the enum
        if (Multiplier == multiplier.Multiplier1) {
            multiplierValue = 1; //initially 0.5 in the docs but set to 1 cause of underflow
        } else if (Multiplier == multiplier.Multiplier2) {
            multiplierValue = 2; //initially 1 in the docs
        } else if (Multiplier == multiplier.Multiplier3) {
            multiplierValue = 4; //initially 2 in the docs
        }

        //calculate the total cost
        //  uint costPer = 1000 gwei;
        uint256 totalCost = (
            costPer
            /**
                 * noOfTicket
                 */
                * multiplierValue
        );

        return totalCost;
    }

    function burnAllTicket() public onlyOwner {
        if (msg.sender == address(0)) {
            revert Monadex_zeroAddress();
        }
        for (uint256 holderIndex = 0; holderIndex < holders.length; holderIndex++) {
            address holder = holders[holderIndex];
            uint256 balance = balanceOf(holder);
            burn(holder, balance);
        }
        s_status = status.closed;
        // distributeTotalAmount();
    }
    //remove completed state
    function setState(uint256 stateStatus) public {
        if (stateStatus == 0) {
            s_status = status.open;
        }
        if (stateStatus == 1) {
            s_status = status.closed;
        }
        if (stateStatus == 2) {
            s_status = status.unstated;
        }
    }

    // function request6randomNumbers() public onlyOwner {
    //     s_requestID = numberGenerator.requestRandomWords();
    // }

    function getrandomNumber() public onlyOwner returns (uint256 ) {
        uint256 randomWords = numberGenerator. requestRandomWords();
        return randomWords;      
    }
    function getVicinityNumbers() public onlyOwner returns (address[] memory){
        uint rafflers = holders.length;
        uint randomWord = getrandomNumber();
        //note that the logic below is to make sure that the randomword is always greater than 3 and less raffler - 3
        if (randomWord <= 3 ) {
            randomWord += 3;
        }
        if (randomWord >= (rafflers - 3)) {
            randomWord -= 3;
        }

        uint vicinityWinners = 6; //No of winners to be sellected
        address[] memory winners = new address[](vicinityWinners);
        // revert check to ensure that the random number is between  the bound of the loop
        if (randomWord >= rafflers) {
            revert ("random word is more that the numbers of ticket holders");
        }

        //select winner using vicinity of the random number generator
        for (uint i = 0; i < vicinityWinners; ++i) {
            //note on my aim of how the index works, if we have randomWord to be 40 and raffler(total no of people in the raffle draw) from i 0 to i6 hence mathematical it is 40 + i0 -(6/2) = 37, for i1 = 38, for i2 = 39, for i3 = 40, for i4 = 41 and for i5 = 42
            uint index = randomWord + i - (vicinityWinners / 2);
            winners[i] = m_Rafflers[index];
        }
        return winners;

        //layout ideo of calculating the vicinity per random word gotten from vrf
        // if (randomWord < (raffler / 2)) {
        //     uint zeroWinner = randomWord;
        //     uint firstWinner = randomWord + 2;
        //     uint secondWinner = randomWord + 4;
        //     uint thirdWinner = randomWord + 6;
        //     uint fourthWinner = randomWord + 8;
        //     uint fifthWinner = randomWord + 10;

        // } else if (randomWord > (raffler / 2)) {
        //     uint zeroWinner = randomWord;
        //     uint firstWinner = randomWord - 2;
        //     uint secondWinner = randomWord - 4;
        //     uint thirdWinner = randomWord - 6;
        //     uint fourthWinner = randomWord - 8;
        //     uint fifthWinner = randomWord - 10;
        // }
         
    }

    function distributeWinnerBalance(address _tokenAddr) public onlyOwner {
        //oya get the 6 random ticket IDs
        uint256 totalAmount = balanceOf(address(this));
        if (totalAmount == 0) {
            revert Monadex_needMoreThanZero();
        }
        address[] memory winners = getVicinityNumbers();
        uint256 firstWinnerPrice = (totalAmount * 50) / 100; //50% reward
        uint256 secondWinnerPrice = (totalAmount * 15) / 100; //15% reward
        uint256 thirdWinnerPrice = (totalAmount * 5) / 100; //5% reward

        //distribute the funds
        IERC20(_tokenAddr).transfer(winners[0], firstWinnerPrice);
        IERC20(_tokenAddr).transfer(winners[1], secondWinnerPrice);
        IERC20(_tokenAddr).transfer(winners[2], secondWinnerPrice);
        IERC20(_tokenAddr).transfer(winners[3], thirdWinnerPrice);
        IERC20(_tokenAddr).transfer(winners[4], thirdWinnerPrice);
        IERC20(_tokenAddr).transfer(winners[5], thirdWinnerPrice);
    }

    ////////////////////
    ////get function////
    ///////////////////



    function _balanceOf(address holder) public view returns (uint256) {
        return balanceOf(holder);
    }
}
