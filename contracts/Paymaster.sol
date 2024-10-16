// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./library/UserOperation.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract Paymaster {
    using ECDSA for bytes32;

    address public immutable owner;
    address public immutable verifyingSigner;
    address public immutable entryPoint;

    error Paymaster__SIG_VALIDATION_FAILED();

    constructor(address _owner, address _verifyingSigner, address _entryPoint) {
        owner = _owner;
        verifyingSigner = _verifyingSigner;
        entryPoint = _entryPoint;
    }

    /**
     * Suppose that the user wants to execute an operation on the supported entry point.
     * paymasterAndData[:20] : address(this)
     * paymasterAndData[20:] : signature
     * @param userOp The user operation to validate
     */
    function validatePaymasterOp(
        UserOperation calldata userOp
    ) public view returns (bool) {
        if (
            verifyingSigner !=
            MessageHashUtils.toEthSignedMessageHash(getHash(userOp)).recover(
                userOp.paymasterAndData[20:]
            )
        ) {
            revert Paymaster__SIG_VALIDATION_FAILED();
        }
        return true;
    }

    function getHash(
        UserOperation memory userOp
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    userOp.sender,
                    userOp.nonce,
                    keccak256(userOp.initCode),
                    keccak256(userOp.callData),
                    userOp.callGasLimit,
                    userOp.verificationGasLimit,
                    userOp.preVerificationGas,
                    userOp.maxFeePerGas,
                    userOp.maxPriorityFeePerGas,
                    block.chainid,
                    address(this)
                )
            );
    }
}
