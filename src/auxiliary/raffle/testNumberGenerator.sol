// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { MonadexRandomGenerator } from "../raffle/MonadexRandomGenerator.sol";

contract tester {
    address[] buyers;

    function get6randomNumbers() public returns (uint256[] memory) {
        //note that the number generated must not be more than the numbers length of the address in buyers array
        
        
        // (bool fulfilled, uint256[] memory randomWords) =
        //     numberGenerator.getRequestStatus(s_requestID);
        // require(fulfilled, "Random numbers have not been gotten yet.");

        // TicketInfo[] memory winners = new TicketInfo[](randomWords.length);
        // for (uint256 i = 0; i < randomWords.length; i++) {
        //     for (uint256 j = 0; j < 3; /*multiplierLength*/ j++) {
        //         address buyerReward1 = m_multiplierBuyerStorage[randomWords[i]][multiplier(j)];

        //         winners[i] = TicketInfo({ ticketID: randomWords[i], buyer: buyerReward1 });

        //         m_winners[ticketID][i] = winners[i];
        //     }
        // }

        // return winners;
    }

    function distributegottenNumbers() public { }

        // function getWinnersByRaffleID(uint256 _RaffleID) public view returns (TicketInfo[] memory) {
    //     _RaffleID = raffleID;
    //     // Directly access the array of TicketInfo structs associated with the ticket ID
    //     return m_winners[_RaffleID];
    // }
}
