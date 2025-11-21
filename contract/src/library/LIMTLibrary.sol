// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;
import {Poseidon2} from "../../lib/zk-mixer-cu/contracts/lib/poseidon2-evm/src/Poseidon2.sol";
// Add import for Field type
import {Field} from "../../lib/zk-mixer-cu/contracts/lib/poseidon2-evm/src/Field.sol";

/// @title IMTLibrary.
/// @author Ola Hamid.
/// @notice The library holds the logic for genration Field constant and zero in respect to depth.
library LIMTLibrary{ 
    error LIMT_DepthCannotBeZero();
    error LIMT_DepthCannotBeMoreThan32();
    error LIMT_LevelOutOfBounds();
    error LIMT__IncrementalMerkleTreeFull(uint32 leave);

    event LIMT_Deposited(bytes32 _commitment, uint256 nextLeaf, uint256 timestamp);

    // the max value of a feild size is 21888242871839275222246405745257275088548364400416034343698204186575808495617
    uint256 public constant c_FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

    function toField(bytes32 a) internal pure returns (Field.Type b) {
        assembly {
            b := a
        }
        Field.checkField(b);
    }
    /**
     * @notice Builds the zero hashes AKA placeholder, for each level of the merkle tree.
     * @param _depth the depth of the merkle tree, levels of the tree counting from bottom to top
     * @param _PHash0 the placeholder hash for level 0
     */
    function buildZeros(uint32 _depth,bytes memory _PHash0) internal view returns(bytes32[] memory) {
        //Poseidon2 Poseidon = new Poseidon2();
        // allocate the array of bytes32 
        // if depth is 7, we need 8 levels from 0 to 7
        bytes32[] memory zeros = new bytes32[](_depth + 1);

        // calculate the base leaf, starting from level zero 
        bytes32 PHash0 = bytes32(uint256(keccak256(_PHash0)) % c_FIELD_SIZE);

        zeros[0] = PHash0;
        for (uint32 i = 1; i <= _depth; ++i ) {
            Field.Type prev = toField(zeros[i - 1]);
            Field.Type node = Poseidon2.hash_2(prev, prev);
            bytes32 nodeBytes32 = Field.toBytes32(node);

            zeros[i] = nodeBytes32;
        }    
        return zeros;
    }

    function LRToLeafHash(
        bytes32 _left, 
        bytes32  _right 
    ) internal view returns(bytes32){
        // check, that the left bytes32 is not a bytes32 of zero 

        Field.Type left_to_Field = toField(_left);
        Field.Type right_to_Field = toField(_right);


        Field.Type leafHash = Poseidon2.hash_2(left_to_Field, right_to_Field);
        bytes32 bytes32LeafHash = Field.toBytes32(leafHash);

        return bytes32LeafHash;
    }
}