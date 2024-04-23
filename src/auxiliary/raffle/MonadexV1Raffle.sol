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

contract MonadexV1Raffle is Ownable {
    using SafeERC20 for IERC20;
    using Address for address;
    /////////////////////
    ///state variables///
    /////////////////////

    IERC20 internal s_monad; //eth sapolia will be representing monad for now
    MonadexRandomGenerator internal numberGenerator; // for genersating numbers
    // raffleInformation internal raffleInfo;
    uint256 internal s_requestID; //reqest ID for random number generator

    // uint8 public s_sizeOfLottery;
    uint256 public ticketID;
    uint256 public startingTimestamp;
    uint256 public closingTimestamp;
    status public s_status;
    uint256 public costPer;
    uint256 public raffleID;

    ///////////
    ///ERROR///
    //////////
    error Monadex_TicketIDNotCorrect();
    error Monadex_needMoreThanZero();
    error Monadex_zeroAddress();
    error Monad_InsufficientFund();
    error Monadex_InvalidRaffleState();

    ///////////
    ///ENUM///
    //////////
    enum status {
        unstated, //notstated, the lottery has not stated yet
        open, //open, the lottery is open
        closed, //the raffle is closed for any more ticket
        completed //the lottery is closed and completed

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
    struct TicketInfo {
        uint256 ticketID;
        address buyer;
    }

    // mapping(address => raffleInformation) internal m_raffleInfoStorage;
    mapping(uint256 => mapping(multiplier => address)) internal m_multiplierBuyerStorage;
    mapping(uint256 => TicketInfo[]) public m_winners;

    /////////////////
    ///constructor///
    ////////////////
    constructor(address _monad, address _IRandomGenerator, uint256 _costPer) Ownable(msg.sender) {
        if (_monad == address(0) && _IRandomGenerator == address(0)) {
            revert Monadex_zeroAddress();
        }

        s_monad = IERC20(_monad);
        numberGenerator = MonadexRandomGenerator(_IRandomGenerator);
        costPer = _costPer;
    }

    ///////////////////
    ///set Functions///
    ///////////////////
    function initialise(uint256 TimeDuration /* awwek ~ 604,800*/ ) public onlyOwner {
        s_status = status.open;
        startingTimestamp = block.timestamp;
        if (closingTimestamp == startingTimestamp + TimeDuration) {
            burnTicket();
            raffleID++;
        }
    }

    function buyTicket(multiplier Multiplier, uint256 noOfTicket) public payable {
        uint256 totalCost = calculateTotalCostInTicket(Multiplier, noOfTicket);
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
        s_monad.transferFrom(msg.sender, address(this), totalCost);
        m_multiplierBuyerStorage[ticketID][Multiplier] = msg.sender;
        // s_raffleIDCounts.push(ticketID);
        ticketID++;
    }

    function calculateTotalCostInTicket(
        multiplier Multiplier,
        uint256 noOfTicket
    )
        internal
        returns (uint256)
    {
        costPer = 100 gwei;
        uint256 multiplierValue;
        //set the enum
        if (Multiplier == multiplier.Multiplier1) {
            multiplierValue = 1; //initially 0.5 in the docs but set to 1 cause of underflow
        } else if (Multiplier == multiplier.Multiplier2) {
            multiplierValue = 2; //initially 2.0 in the docs
        } else if (Multiplier == multiplier.Multiplier3) {
            multiplierValue = 4;
        }

        //calculate the total cost
        //  uint costPer = 1000 gwei;
        uint256 totalCost = (costPer * noOfTicket * multiplierValue);

        return totalCost;
    }

    function burnTicket() public onlyOwner {
        s_status = status.closed;
        ticketID = 0;

        // distributeTotalAmount();
    }

    function setState(uint256 stateStatus) public {
        if (stateStatus == 0) {
            s_status = status.open;
        }
        if (stateStatus == 1) {
            s_status = status.closed;
        }
        if (stateStatus == 2) {
            s_status = status.completed;
        }
        if (stateStatus == 3) {
            s_status = status.unstated;
        }
    }

    function request6randomNumbers() public onlyOwner {
        s_requestID = numberGenerator.requestRandomWords();
    }

    function get6randomNumbers() public onlyOwner returns (TicketInfo[] memory) {
        (bool fulfilled, uint256[] memory randomWords) =
            numberGenerator.getRequestStatus(s_requestID);
        require(fulfilled, "Random numbers have not been gotten yet.");

        TicketInfo[] memory winners = new TicketInfo[](randomWords.length);
        for (uint256 i = 0; i < randomWords.length; i++) {
            for (uint256 j = 0; j < 3; /*multiplierLength*/ j++) {
                address buyerReward1 = m_multiplierBuyerStorage[randomWords[i]][multiplier(j)];

                winners[i] = TicketInfo({ ticketID: randomWords[i], buyer: buyerReward1 });

                m_winners[ticketID][i] = winners[i];
            }
        }

        return winners;
    }

    function distributeWinnerBalance() public onlyOwner {
        //oya get the 6 random ticket IDs
        uint256 totalAmount = s_monad.balanceOf(address(this));
        if (totalAmount == 0) {
            revert Monadex_needMoreThanZero();
        }
        TicketInfo[] memory winners = get6randomNumbers();
        uint256 firstWinnerPrice = (totalAmount * 50) / 100; //50% reward
        uint256 secondWinnerPrice = (totalAmount * 15) / 100; //15% reward
        uint256 thirdWinnerPrice = (totalAmount * 5) / 100; //5% reward

        //distribute the funds
        s_monad.transfer(winners[0].buyer, firstWinnerPrice);
        s_monad.transfer(winners[1].buyer, secondWinnerPrice);
        s_monad.transfer(winners[2].buyer, secondWinnerPrice);
        s_monad.transfer(winners[3].buyer, thirdWinnerPrice);
        s_monad.transfer(winners[4].buyer, thirdWinnerPrice);
        s_monad.transfer(winners[5].buyer, thirdWinnerPrice);
    }

    function getWinnersByRaffleID(uint256 _RaffleID) public view returns (TicketInfo[] memory) {
        _RaffleID = raffleID;
        // Directly access the array of TicketInfo structs associated with the ticket ID
        return m_winners[_RaffleID];
    }
}
