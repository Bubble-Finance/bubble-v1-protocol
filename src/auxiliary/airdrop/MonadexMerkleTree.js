/// @title MonadexMerkleTree.js
/// @author Ola Hamid
/// @notice This script generates a Merkle tree for the MonadexV1AirdropManager, ensuring efficient and secure verification of participant eligibility.
/// @notice The Merkle tree is constructed from a list of eligible addresses and their airdrop amounts, enabling scalable verification without the need to check every entry.

// run in terminal to get merkleTree: node src/auxiliary/airdrop/MonadexMerkleTree.js 


const { StandardMerkleTree } = require("../../../node_modules/@openzeppelin/merkle-tree");
const fs = require("fs");

// get values for each leaves
const airdropValue = [
    ["0x1234567890123456789012345678901234567890", "0", "1000000000000"] ,
    ["0x2345678901234567890123456789012345678901", "1", "1000000000000"] ,
    ["0x3456789012345678901234567890123456789012", "2", "1000000000000"],
    ["0x4567890123456789012345678901234567890123", "3", "1000000000000"]    
];

//setting the tree from the airdrop value
const tree = StandardMerkleTree.of(airdropValue, ["address", "uint256", "uint256"]);

console.log("Merkle Root:", tree.root);

fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));
