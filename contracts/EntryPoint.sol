// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./StakeManager.sol";
import "./library/PostOpMode.sol";
import "./library/UserOperation.sol";

contract EntryPoint is StakeManager {
    function handleOps(UserOperation[] calldata userOps) public {
        uint256 gasUsed = 0;

        for (uint i = 0; i < userOps.length; i++) {
            gasUsed += handleOp(userOps[i]);
        }

        payable(msg.sender).transfer(gasUsed);
    }

    function handleOp(UserOperation calldata userOp) public returns (uint256) {
        uint256 preGas = gasleft();
        uint256 gasUsed = 0;
        address paymaster = address(bytes20(userOp.paymasterAndData[:20]));
        bool nonePaymaster = paymaster == address(0);
        uint256 _verificationGasLimit = userOp.verificationGasLimit;
        uint256 _callGasLimit = userOp.callGasLimit;
        address _sender = userOp.sender;
        uint256 _preVerificationGas = userOp.preVerificationGas;

        // calculate required payment
        // If using a Paymaster, the verificationGasLimit is used also to as a limit for the postOp call. The security model might call postOp eventually twice
        uint256 mul = nonePaymaster ? 1 : (1 + 2);
        uint256 requiredGas = _callGasLimit +
            _verificationGasLimit *
            mul +
            _preVerificationGas;

        uint256 _maxFeePerGas = userOp.maxFeePerGas;
        uint256 _maxPriorityFeePerGas = userOp.maxPriorityFeePerGas;
        uint256 gasPrice = (_maxFeePerGas == _maxPriorityFeePerGas)
            ? _maxFeePerGas
            : min(_maxFeePerGas, _maxPriorityFeePerGas + block.basefee);
        uint256 requiredPayment = gasPrice * requiredGas;

        uint256 beforeVerifyGas = gasleft();
        uint256 missingAccountFunds = 0;
        // If there is no paymaster, the sender should pay for the operation himself
        if (nonePaymaster) {
            uint256 bal = balanceOf(_sender);
            missingAccountFunds = bal > requiredPayment
                ? 0
                : requiredPayment - bal;
        }
        // validateOp
        {
            (bool valid, bytes memory data) = _sender.call(
                abi.encodeWithSignature(
                    "validateOp((address,uint256,bytes,bytes,uint256,uint256,uint256,uint256,uint256,bytes,bytes), uint256)",
                    userOp,
                    missingAccountFunds
                )
            );
            require(valid, _getRevertReason(data));
            bool success = abi.decode(data, (bool));
            require(success);
        }

        if (nonePaymaster) {
            DepositInfo storage senderInfo = deposits[_sender];
            uint256 deposit = senderInfo.depositAmount;
            require(requiredPayment <= deposit, "Insufficient sender deposit");
            senderInfo.depositAmount = uint112(deposit - requiredPayment);
        }

        gasUsed = beforeVerifyGas - gasleft();
        require(
            gasUsed <= _verificationGasLimit,
            "exceed verification gas limit"
        );

        // validate paymaster
        if (!nonePaymaster) {
            uint256 lastGasLimit = _verificationGasLimit - gasUsed;
            {
                DepositInfo storage depositInfo = deposits[paymaster];
                uint256 _depositAmount = depositInfo.depositAmount;
                require(
                    _depositAmount >= requiredPayment,
                    "Insufficient paymaster deposit"
                );
                depositInfo.depositAmount = uint112(
                    _depositAmount - requiredPayment
                );
            }
            (bool valid2, bytes memory data2) = paymaster.call{
                gas: lastGasLimit
            }(
                abi.encodeWithSignature(
                    "validatePaymasterOp((address,uint256,bytes,bytes,uint256,uint256,uint256,uint256,uint256,bytes,bytes))",
                    userOp
                )
            );
            require(valid2, _getRevertReason(data2));
            bool success2 = abi.decode(data2, (bool));
            require(success2);
        }

        // Execute the operation
        (bool callSuccess, ) = _sender.call{gas: _callGasLimit}(
            userOp.callData
        );
        require(callSuccess, "Operation execution failed");

        return preGas - gasleft() + _preVerificationGas;
    }

    //// internal
    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x > y ? y : x;
    }

    // Function to decode the revert reason
    function _getRevertReason(
        bytes memory revertData
    ) internal pure returns (string memory) {
        // If the revert reason is the standard revert (starts with 0x08c379a0)
        if (
            revertData.length >= 68 &&
            revertData[0] == 0x08 &&
            revertData[1] == 0xc3 &&
            revertData[2] == 0x79 &&
            revertData[3] == 0xa0
        ) {
            // Remove the first 4 bytes (function selector for Error(string))
            bytes memory revertReason = slice(
                revertData,
                4,
                revertData.length - 4
            );

            // Decode the revert reason string
            return abi.decode(revertReason, (string));
        } else {
            return "Unknown error format";
        }
    }

    // Helper function to slice a bytes array
    function slice(
        bytes memory data,
        uint start,
        uint len
    ) internal pure returns (bytes memory) {
        bytes memory result = new bytes(len);
        for (uint i = 0; i < len; i++) {
            result[i] = data[i + start];
        }
        return result;
    }
}
