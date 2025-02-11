// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/GoldToken.sol";
import "../src/GoldTokenMock.sol";

contract GoldTokenTest is Test {
    GoldTokenMock public goldTokenMock;
    address vrfCoordinator = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625; // VRF Coordinator (Sepolia)
    address linkToken = 0x779877A7B0D9E8603169DdbD7836e478b4624789; // LINK Token (Sepolia)

    function setUp() public {
        goldTokenMock = new GoldTokenMock(
            vrfCoordinator,
            linkToken,
            0x6c3699283bda56ad74f6b855546325b68d482e983852a5ccba7487b572fcd28c, // Mock keyHash
            0.1 ether, // Fee
            address(this)
        );

        // Ajouter des fonds LINK au contrat pour permettre les appels à requestRandomWinner
        deal(
            0x779877A7B0D9E8603169DdbD7836e478b4624789,
            address(goldTokenMock),
            1 ether
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
        goldTokenMock.requestRandomWinner();

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
