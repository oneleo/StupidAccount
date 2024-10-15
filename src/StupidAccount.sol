// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import {IEntryPoint} from "@aa/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@aa/interfaces/PackedUserOperation.sol";
import {PaymasterMode} from "src/StupidPaymaster.sol";

contract StupidAccount {
    IEntryPoint public immutable entryPoint;

    constructor(IEntryPoint anEntryPoint) {
        entryPoint = anEntryPoint;
    }

    function buildStupidUserOp(address paymaster, PaymasterMode paymasterMode)
        external
        view
        virtual
        returns (PackedUserOperation memory packedUserOperation)
    {
        address sender = address(this);
        uint256 DEFAULT_VERIFICATION_GAS = 1000000; // 1M gas
        uint256 DEFAULT_EXECUTION_GAS = 1500000; // 1.5M gas

        bytes16 paymasterVerificationGasLimit = bytes16(abi.encodePacked(uint128(500000)));
        bytes16 paymasterPostOpGasLimit = bytes16(abi.encodePacked(uint128(500000)));

        uint48 validAfter = uint48(123);
        uint48 validUntil = uint48(456);
        uint256 maxCostAllowed = (1 ether * 105) / 100;

        bytes memory modeAndValidityData = abi.encodePacked(paymasterMode, validAfter, validUntil, maxCostAllowed);

        bytes memory paymasterAndData = abi.encodePacked(
            paymaster, // Paymaster address
            bytes.concat(paymasterVerificationGasLimit, paymasterPostOpGasLimit, modeAndValidityData)
        );

        return PackedUserOperation({
            sender: sender,
            nonce: IEntryPoint(entryPoint).getNonce(sender, 0),
            initCode: bytes(""),
            callData: bytes(""),
            accountGasLimits: bytes32(abi.encodePacked(uint128(DEFAULT_VERIFICATION_GAS), uint128(DEFAULT_EXECUTION_GAS))),
            preVerificationGas: 0,
            gasFees: bytes32(abi.encodePacked(uint128(1), uint128(1))),
            paymasterAndData: paymasterAndData,
            signature: bytes("")
        });
    }

    function validateUserOp(
        PackedUserOperation calldata, /* userOp */
        bytes32, /* userOpHash */
        uint256 missingAccountFunds
    ) external virtual returns (uint256 validationData) {
        _requireFromEntryPoint();
        _payPrefund(missingAccountFunds);
        return 0;
    }

    function _requireFromEntryPoint() internal view virtual {
        require(msg.sender == address(entryPoint), "account: not from EntryPoint");
    }

    function _payPrefund(uint256 missingAccountFunds) internal virtual {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            (success);
            //ignore failure (its EntryPoint's job to verify, not account.)
        }
    }
}
