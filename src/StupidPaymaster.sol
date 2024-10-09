// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "@oz/access/Ownable.sol";
import {IEntryPoint} from "@aa/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@aa/interfaces/PackedUserOperation.sol";

enum PaymasterMode {
    Sponsor,
    ChargeInPostOp
}

uint256 constant PAYMASTER_MODE_OFFSET = 52;
uint256 constant PAYMASTER_VALID_AFTER_OFFSET = PAYMASTER_MODE_OFFSET + 1;
uint256 constant PAYMASTER_VALID_UNTIL_OFFSET = PAYMASTER_VALID_AFTER_OFFSET + 6;
uint256 constant PAYMASTER_MAX_COST_ALLOWED_OFFSET = PAYMASTER_VALID_UNTIL_OFFSET + 6;

contract StupidPaymaster is Ownable {
    IEntryPoint public immutable entryPoint;
    bool public shouldPostOpFail;

    enum PostOpMode {
        // User op succeeded.
        opSucceeded,
        // User op reverted. Still has to pay for gas.
        opReverted,
        // Only used internally in the EntryPoint (cleanup after postOp reverts). Never calling paymaster with this value
        postOpReverted
    }

    struct ValidationData {
        address aggregator;
        uint48 validAfter;
        uint48 validUntil;
    }

    event UserOpProcessed(
        bytes32 indexed userOpHash,
        address indexed userOpSender,
        bytes32 indexed signerDataHash,
        PaymasterMode mode,
        uint256 actualGasCost,
        address token,
        uint256 actualTokenCost,
        address chargeFrom,
        bool chargeSuccessful
    );

    constructor(IEntryPoint _entryPoint) Ownable(msg.sender) {
        entryPoint = _entryPoint;
    }

    function setShouldPostOpFail(bool _shouldPostOpFail) external onlyOwner {
        shouldPostOpFail = _shouldPostOpFail;
    }

    function validatePaymasterUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 maxCost)
        external
        returns (bytes memory context, uint256 validationData)
    {
        _requireFromEntryPoint();
        return _validatePaymasterUserOp(userOp, userOpHash, maxCost);
    }

    function _validatePaymasterUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 /* maxCost */ )
        internal
        virtual
        returns (bytes memory context, uint256 validationData)
    {
        (PaymasterMode mode,,,) = _decodeModeAndValidityData(userOp.paymasterAndData);

        return (
            abi.encode(userOpHash, userOp.sender, mode),
            _packValidationData({sigFailed: false, validUntil: 0, validAfter: 9999999})
        );
    }

    function _decodeModeAndValidityData(bytes calldata paymasterAndData)
        internal
        pure
        returns (PaymasterMode mode, uint48 validAfter, uint48 validUntil, uint256 maxCostAllowed)
    {
        mode = PaymasterMode(uint8(bytes1(paymasterAndData[PAYMASTER_MODE_OFFSET])));
        validAfter = uint48(bytes6(paymasterAndData[PAYMASTER_VALID_AFTER_OFFSET:PAYMASTER_VALID_AFTER_OFFSET + 6]));
        validUntil = uint48(bytes6(paymasterAndData[PAYMASTER_VALID_UNTIL_OFFSET:PAYMASTER_VALID_UNTIL_OFFSET + 6]));
        maxCostAllowed =
            uint256(bytes32(paymasterAndData[PAYMASTER_MAX_COST_ALLOWED_OFFSET:PAYMASTER_MAX_COST_ALLOWED_OFFSET + 32]));
    }

    function _packValidationData(bool sigFailed, uint48 validUntil, uint48 validAfter) public pure returns (uint256) {
        return (sigFailed ? 1 : 0) | (uint256(validUntil) << 160) | (uint256(validAfter) << (160 + 48));
    }

    function postOp(PostOpMode mode, bytes calldata context, uint256 actualGasCost, uint256 actualUserOpFeePerGas)
        external
    {
        _requireFromEntryPoint();
        _postOp(mode, context, actualGasCost, actualUserOpFeePerGas);
    }

    function _postOp(
        PostOpMode, /* mode */
        bytes calldata context,
        uint256 actualGasCost,
        uint256 /* actualUserOpFeePerGas */
    ) internal virtual {
        (bytes32 userOpHash, address userOpSender, PaymasterMode mode) = _decodeContext(context);

        if (mode == PaymasterMode.Sponsor) {
            emit UserOpProcessed(
                userOpHash,
                userOpSender,
                bytes32(uint256(0)),
                PaymasterMode.Sponsor,
                actualGasCost,
                address(0),
                0,
                address(0),
                false
            );
        } else {
            bool chargeSuccessful;
            if (!shouldPostOpFail) {
                chargeSuccessful = true;
            }

            emit UserOpProcessed(
                userOpHash,
                userOpSender,
                bytes32(uint256(1)),
                PaymasterMode.ChargeInPostOp,
                actualGasCost,
                address(1),
                1,
                address(1),
                chargeSuccessful
            );
        }
        if (shouldPostOpFail) {
            revert("PostOp failed");
        }
    }

    /**
     * Validate the call is made from a valid entrypoint
     */
    function _requireFromEntryPoint() internal virtual {
        require(msg.sender == address(entryPoint), "Sender not EntryPoint");
    }

    function _decodeContext(bytes calldata context)
        internal
        pure
        returns (bytes32 userOpHash, address userOpSender, PaymasterMode mode)
    {
        return abi.decode(context, (bytes32, address, PaymasterMode));
    }
}
