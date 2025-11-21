// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {LIMTLibrary} from "../library/LIMTLibrary.sol";
import {Field} from "../../lib/zk-mixer-cu/contracts/lib/poseidon2-evm/src/Field.sol";

/// @title IncrementalMerkleTree.
/// @author Ola Hamid.
/// @notice This contract implements an incremental Merkle tree with a fixed depth.
/// It allows for the insertion of new leaves and maintains the Merkle root.
/// The tree uses the Poseidon hash function for hashing nodes.
/// The tree is initialized with zero hashes for each level, which are precomputed.
/// The contract ensures that the depth is within a valid range (1 to 31).
/// The tree supports efficient updates and root retrieval.
/// Note: This implementation does not include proof generation or verification.    
contract IncrementalMerkleTree {


    // takling and storing our fixed height of the merkle Tree
    uint32 public immutable i_depth;

    bytes32 public s_root;
    string public s_placeHolder;

    uint32 public s_nextLeafIndex;

    uint32 public immutable i_maxLeaves;
    mapping (uint32 => bytes32) public m_cachedSubTree;
    constructor (uint32 _depth, string memory _placeHolder) {
        if (_depth == 0) {
            revert LIMTLibrary.LIMT_DepthCannotBeZero();
        }
        if (_depth >= 32 ) {
            revert LIMTLibrary.LIMT_DepthCannotBeMoreThan32();
        }
        i_depth = _depth;
        i_maxLeaves = uint32(1) << _depth; // 2 ** _depth
        s_placeHolder = _placeHolder;
        // initialize the merkle tree with default values in zeroes values

        // store the initial root in stoarage location
        s_root = zero(_depth, s_placeHolder);
    }

    function insert(bytes32 _leaf) internal returns(uint32) {

        // add the leaf to the incremental merkle tree
        uint32 _nextLeafIndex = s_nextLeafIndex;
        // check that the index of the leaf being added is within the max index of the tree
        if (_nextLeafIndex >= i_maxLeaves) {
            revert LIMTLibrary.LIMT__IncrementalMerkleTreeFull(_nextLeafIndex);
        }
        // figure out if the index is even or odd
        // if even we need to put it on the left of the hash and a zero tree on the right the result is the cashed subtree 
        uint32 currentIndex = _nextLeafIndex;
        bytes32 currentHash = _leaf;
        bytes32 left;
        bytes32 right;
        for (uint32 i = 0; i < i_depth; ++i) {
            if (_nextLeafIndex % 2 == 0) {
                left = currentHash;
                right = zero(i, s_placeHolder);
                m_cachedSubTree[i] = currentHash;
            } else {
                // if odd, that means the left siblings must have been processed before, earlier as current hash
                left = m_cachedSubTree[i];
                right = currentHash;
            }
            currentHash = LIMTLibrary.LRToLeafHash(left, right);

            currentIndex = currentIndex / 2;
        }
        s_root = currentHash;
        s_nextLeafIndex = _nextLeafIndex + 1;

        return _nextLeafIndex;
    }

    // create zereos function
    // since we are using peisiodon hash function, it has a feild size that is less than max size of the keccak256 hash function
    // so we can not use keccak256 hash function to create the zeroes values, we need to do % with the field size
    // i assume is the index right? i is the depth that increment through the levels
    // remember PHash0, hash1 are the zero values for each level and thety are just place holder for the merkel tree to filling the actuall value in
    // whats this function does it let you calculate the root fo the merkle tree with the zero values(placeholders)

    function zero(
        uint32 depth,
        string memory _TreeName
    )
        internal 
        view
        returns(bytes32) 
    {

        if (depth == 0 || depth > 31) {
            revert LIMTLibrary.LIMT_LevelOutOfBounds();
        }

        bytes memory PHash0 = abi.encodePacked(_TreeName, "Level 0");
        bytes32[] memory zeros = LIMTLibrary.buildZeros(depth, PHash0);
        return zeros[depth];
    }

}