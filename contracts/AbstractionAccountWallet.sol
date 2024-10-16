// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./library/UserOperation.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract AbstractionAccountWallet {
    using ECDSA for bytes32;

    address public immutable owner;
    address public immutable entryPoint;
    uint256 public nonce;

    error AbstractionAccountWallet__Not_Owner();
    error AbstractionAccountWallet__Not_Entry_Point();
    error AbstractionAccountWallet__SIG_VALIDATION_FAILED();
    error AbstractionAccountWallet__NONCE_VALIDATION_FAILED();

    event ExecutedOperation(address indexed sender, uint256 value, bytes data);

    modifier onlyOwner() {
        if (owner != msg.sender) revert AbstractionAccountWallet__Not_Owner();
        _;
    }

    modifier onlyEntryPoint() {
        if (entryPoint != msg.sender)
            revert AbstractionAccountWallet__Not_Entry_Point();
        _;
    }

    constructor(address _entryPoint) {
        owner = msg.sender;
        entryPoint = _entryPoint;
        nonce = 0;
    }

    // Function to validate a user-defined operation
    function validateOp(
        UserOperation memory userOp,
        uint256 requiredPayment
    ) public returns (bool) {
        // check nonce
        if (userOp.nonce != nonce++)
            revert AbstractionAccountWallet__NONCE_VALIDATION_FAILED();
        // check signature
        if (
            owner !=
            MessageHashUtils.toEthSignedMessageHash(getHash(userOp)).recover(
                userOp.signature
            )
        ) {
            revert AbstractionAccountWallet__SIG_VALIDATION_FAILED();
        }

        // send requiredPayment to entryPoint
        if (requiredPayment != 0) payable(entryPoint).transfer(requiredPayment);

        return true;
    }

    function getHash(
        UserOperation memory userOp
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    bytes32(block.chainid),
                    userOp.sender,
                    userOp.nonce,
                    keccak256(userOp.initCode),
                    keccak256(userOp.callData),
                    userOp.callGasLimit,
                    userOp.verificationGasLimit,
                    userOp.preVerificationGas,
                    userOp.maxFeePerGas,
                    userOp.maxPriorityFeePerGas,
                    keccak256(userOp.paymasterAndData),
                    entryPoint
                )
            );
    }
}
