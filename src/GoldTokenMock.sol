// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "../src/GoldToken.sol";

contract GoldTokenMock is GoldToken {
    constructor(
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _keyHash,
        uint256 _fee,
        address initialOwner
    ) GoldToken(_vrfCoordinator, _linkToken, _keyHash, _fee, address(this)) {}

    // Expose fulfillRandomness for testing
    function testFulfillRandomness(
        bytes32 requestId,
        uint256 randomness
    ) public {
        fulfillRandomness(requestId, randomness);
    }
}
