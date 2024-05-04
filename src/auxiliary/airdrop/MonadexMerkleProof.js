/// @title MonadexMerkleProof.js
/// @author Ola Hamid
/// @notice This script is part of the MonadexV1AirdropManager. It generates and verifies Merkle proofs for participants to claim their airdrop.
/// @notice The script loads the Merkle tree structure from a JSON file, facilitating the distribution of the Merkle root and proofs to participants. Participants use these proofs to verify their eligibility and claim their airdrop.

// run in terminal to get merkleProof: node src/auxiliary/airdrop/MonadexMerkleProof.js 


const { StandardMerkleTree } = require("../../../node_modules/@openzeppelin/merkle-tree");
const fs = require("fs");

// tree
const tree = StandardMerkleTree.load(JSON.parse(fs.readFileSync("tree.json")));

// use a for loop to get the proof of each address
for (const [i, v] of tree.entries()) {
    if (v[0] === "0x1234567890123456789012345678901234567890") {
        const proof = tree.getProof(i);
        console.log("value:", v);
        console.log("proof:", proof);
    }
}