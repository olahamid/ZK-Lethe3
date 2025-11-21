
// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IncrementalMerkleTree} from "../core/LetheIncrementalMerkleTree.sol";
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {LIMTLibrary} from "../../src/library/LIMTLibrary.sol";
contract Lethe is ERC20, IncrementalMerkleTree {
    using SafeERC20 for IERC20;

    error Lethe__NotProtocolAddrCaller(address _Addr);
    error Lethe__TokenNotSupported(address _tokenAddress);
    error Lethe__CommitmentAlreadyAdded(bytes32 _commitment);
    error Lethe__MultiplierNotRight(uint8 _multiplier);
    error Lethe__WrongDenominatorSent(uint256 _sent, uint256 _required);

    struct tokenConfig {
        uint256 baseDenominator;
        uint256 mulNum;
        uint256 mulDen;
        bool isSupported;
    }

    //IVerifier public immutable i_verifier; 
    address public immutable i_LetheProtocolAddress;
    uint256 public s_ETH_Denominator;
    uint256 public constant PRECISION = 1e18;
    address public immutable ETH_NATIVE;
    // @notice the multiplier must have the highest multiplier as 20
    mapping (address tokenAddress => tokenConfig) public m_TokenConfigs;
    mapping (bytes32 __commitement => bool ) public m_Commitment;  

    constructor(
        //IVerifier _verifier,
        address _letheProtocolAddress,
        uint256 _ETH_denominator,
        uint32 _MerkleTreeDepth,
        string memory _ZRplaceHolder
    ) 
        IncrementalMerkleTree(_MerkleTreeDepth, _ZRplaceHolder)
        ERC20("LETHE RIVER", "LETHE")
    {
        //i_verifier = _verifier;

        i_LetheProtocolAddress = _letheProtocolAddress;
        s_ETH_Denominator = _ETH_denominator;

        m_TokenConfigs[address(0)] = tokenConfig({
            baseDenominator: _ETH_denominator,
            mulNum: 1 * PRECISION,
            mulDen: 1 * PRECISION,
            isSupported: true
        });

    }
    modifier onlyLetheProtocol() {
        if (msg.sender != i_LetheProtocolAddress) {
            revert Lethe__NotProtocolAddrCaller(msg.sender);
        }
        _;
    }

    /**
     * @notice function to support a new token in the protocol
     * @param _tokenAddress the address of the token to be supported
     * @param _mulNum the numerator of the multiplier fraction
     * @param _mulDen the denominator of the multiplier fraction
     */
    function supportToken(
        address _tokenAddress, 
        uint256 _mulNum,
        uint256 _mulDen
    )
        public 
        onlyLetheProtocol
    {
        tokenConfig memory _tokenConfig;
        _tokenConfig = tokenConfig({
            baseDenominator: s_ETH_Denominator,
            mulNum: _mulNum * PRECISION,
            mulDen: _mulDen * PRECISION,
            isSupported: true
        });
        m_TokenConfigs[_tokenAddress] = _tokenConfig;

    }

    function computeDepositAmount(
        address _tokenAddress,
        uint8 _multipler,
        address tokenAddress
    ) 
        private 
        view 
        returns (uint256)
    {
        tokenConfig memory _tokenConfig = m_TokenConfigs[_tokenAddress];
        if(!_tokenConfig.isSupported) {
            revert Lethe__TokenNotSupported(_tokenAddress);
        }

        // get the current chainlinkUpkeep amount of the tokenNUM
        // get the current chanlink upkeep amount of the tokenDEM ~ Native or Lethe Currency
        (uint256 tokenNum, uint256 tokenDem) = doChainlinkUpKeep();
        // get the decimal of the token of native currency tokenDEM 1e18 
        uint256 decimalDem = PRECISION;
        // get the decimal of the token of tokenNUM currency
        ERC20 token = ERC20(tokenAddress);
        uint8 decimalNum = token.decimals();
        // do the decimal fight(NUM/DEM )
        uint256 decimalFight = (decimalNum / decimalDem);
        uint256 AmountToDeposit =  ((_tokenConfig.baseDenominator* _multipler * tokenNum) / (tokenDem / decimalFight));
        return AmountToDeposit;
    }

    /**
     * @notice function to deposit ETH into the protocol
     * @param _commitment the commitment to be added, The Poseidon hash of the user's (off-chain generated) nullifier and secret.
     * @param _multiplier the multiplier for the deposit. The amount to be deposited will be calculated as: s_ETH_Denominator * _multiplier
     * The multiplier must be between 1 and 20 (inclusive)
     */
    function depositEth(
        bytes32 _commitment, 
        uint8 _multiplier
    ) 
        public 
        payable
    {
        // check if the multiplier is between 1 and 20
        if(_multiplier < 1 || _multiplier > 20) {
            revert Lethe__MultiplierNotRight(_multiplier);
        }
        // check the commitment if it is used or Not, so to prevent double Deposit
        if(m_Commitment[_commitment]) {
            revert Lethe__CommitmentAlreadyAdded(_commitment);
        }
        // check if the amount sent is the right denominator
        uint256 requiredAmount = computeDepositAmount(address(0), _multiplier, ETH_NATIVE);
        if(msg.value != requiredAmount) {
            revert Lethe__WrongDenominatorSent(msg.value, requiredAmount);
        }
        // This data structure will hold all valid, deposited commitments and its root
        // will be used in the withdrawal process.
        // Example: _insertIntoMerkleTree(_commitment);
        insert(_commitment);
        // update the state variable mapping handling the deposits
        m_Commitment[_commitment] = true;
        // emit it out

    }
    /**
     * @notice function to deposit ERC20 tokens into the protocol
     * @param _commitment the commitment to be added, The Poseidon hash of the user's (off-chain generated) nullifier and secret.
     * @param _multiplier the multiplier for the deposit. The amount to be deposited will be calculated as: s_ETH_Denominator * _multiplier
     * The multiplier must be between 1 and 20 (inclusive)
     * @param tokenAddress the address of the token to be deposited
     */
    function depositErc20(
        bytes32 _commitment,
        uint8 _multiplier, 
        address tokenAddress
    ) 
        public {
        // check if the multiplier is between 1 and 20
        if (_multiplier < 1 || _multiplier> 20 ) {
            revert Lethe__MultiplierNotRight(_multiplier);
        }
        // check if the amount sent is the right denominator
        if(m_Commitment[_commitment]) {
            revert Lethe__CommitmentAlreadyAdded(_commitment);
        }
        // update the state variable mapping handling the deposits
        uint256 requiredAmount = computeDepositAmount(tokenAddress, _multiplier, tokenAddress);
        IERC20 token = IERC20(tokenAddress);
        token.safeTransferFrom(msg.sender, address(this), requiredAmount);
        // if (success != true) {
        //     revert Lethe__WrongDenominatorSent(0, requiredAmount);
        // }
        // update the state variable mapping handling the deposits
        m_Commitment[_commitment] = true;
        // TO-DO: Add _commitment to the on-chain Incremental Merkle Tree.
        // This data structure will hold all valid, deposited commitments and its root
        // will be used in the withdrawal process.
        // Example: _insertIntoMerkleTree(_commitment);
        uint32 nextLeaf = insert(_commitment);
        m_Commitment[_commitment] = true;
        // emit it out
        emit LIMTLibrary.LIMT_Deposited(_commitment, nextLeaf, block.timestamp);
    }

    function withdraw(
        
    )
        public 
    {

    }

    

    // lets play with the idea of having a chainlink function the mulNum and mulDen to be updated periodically depending on the price of the token
    function doChainlinkUpKeep() internal view returns(uint256 _tokenNum, uint256 _tokenDem){

    } 
}