// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/GoldToken.sol";
import "../src/GoldTokenMock.sol";

contract GoldTokenTest is Test {
    GoldTokenMock public goldTokenMock;
    address vrfCoordinator = address(0x123); // Mock VRF Coordinator
    address linkToken = address(0x456); // Mock LINK token

    function setUp() public {
        goldTokenMock = new GoldTokenMock(
            vrfCoordinator,
            linkToken,
            bytes32("0xabc"), // Mock keyHash
            0.1 ether, // Fee
            address(this)
        );
    }

    // Test mint avec des ETH
    function testMint() public {
        // Envoyer 1 ETH pour minter des tokens
        goldTokenMock.mint{value: 1 ether}();
        uint256 tokenBalance = goldTokenMock.balanceOf(address(this));

        // Vérifier que les tokens sont mintés correctement
        assertEq(tokenBalance, 0.95 ether); // Après 5% de frais

        // Vérifier que le pool de loterie est mis à jour
        assertEq(goldTokenMock.lotteryPool(), 0.025 ether); // 2.5% dans le pool
    }

    // Test burn avec des tokens
    function testBurn() public {
        // Mint des tokens
        goldTokenMock.mint{value: 1 ether}();
        uint256 initialTokenBalance = goldTokenMock.balanceOf(address(this));

        // Brûler une partie des tokens
        goldTokenMock.burn(0.5 ether);
        uint256 tokenBalance = goldTokenMock.balanceOf(address(this));

        // Vérifier le solde des tokens après burn
        assertEq(tokenBalance, initialTokenBalance - 0.475 ether); // Après 5% de frais

        // Vérifier que le pool de loterie est mis à jour
        assertEq(goldTokenMock.lotteryPool(), 0.0375 ether); // 2.5% supplémentaire ajouté au pool
    }

    // Test de la loterie
    function testLottery() public {
        // Mint des tokens
        goldTokenMock.mint{value: 1 ether}();
        goldTokenMock.mint{value: 2 ether}();

        // Vérifiez que des participants existent
        uint256 participantsCount = goldTokenMock.getParticipantsCount();
        assertGt(participantsCount, 0, "Participants list should not be empty");

        // Vérifier que le pool de loterie est bien rempli
        uint256 lotteryPool = goldTokenMock.lotteryPool();
        assertGt(lotteryPool, 0, "Lottery pool should have funds");

        // Demander un numéro aléatoire pour la loterie
        // goldTokenMock.requestRandomWinner();

        // Simuler un gagnant aléatoire
        uint256 randomValue = 1; // Index du gagnant
        goldTokenMock.testFulfillRandomness(bytes32("0xabc"), randomValue);

        // Vérifier que le gagnant est enregistré
        address recentWinner = goldTokenMock.recentWinner();
        assertTrue(recentWinner != address(0), "Recent winner should be set");

        // Vérifier que le pool de loterie a été vidé
        assertEq(
            goldTokenMock.lotteryPool(),
            0,
            "Lottery pool should be empty"
        );
    }
}
