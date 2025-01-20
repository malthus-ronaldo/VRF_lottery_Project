// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/src/v0.8/vrf/VRFConsumerBase.sol";

contract GoldToken is
    ERC20,
    ERC20Burnable,
    Ownable,
    ERC20Permit,
    VRFConsumerBase
{
    uint256 public feePercent = 5;
    uint256 public lotteryPool;
    address public recentWinner;

    bytes32 internal keyHash;
    uint256 internal fee;
    address[] private participants;

    constructor(
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _keyHash,
        uint256 _fee,
        address initialOwner
    )
        ERC20("GoldToken", "GT")
        Ownable(initialOwner)
        ERC20Permit("GoldToken")
        VRFConsumerBase(_vrfCoordinator, _linkToken)
    {
        keyHash = _keyHash;
        fee = _fee;
    }

    function mint() external payable {
        require(msg.value > 0, "ETH required to mint tokens");

        uint256 amountToMint = msg.value; // 1 ETH = 1 GOLD
        uint256 feeAmount = (amountToMint * feePercent) / 100; // 5% fees
        uint256 lotteryFee = feeAmount / 2; // 50% des frais pour la loterie
        lotteryPool += lotteryFee;

        uint256 mintAmount = amountToMint - feeAmount; // Montant final après frais

        _mint(msg.sender, mintAmount); // Mint les tokens pour l'utilisateur

        // Ajouter l'utilisateur à la liste des participants
        if (!isParticipant(msg.sender)) {
            participants.push(msg.sender);
        }
    }

    function isParticipant(address participant) public view returns (bool) {
        for (uint256 i = 0; i < participants.length; i++) {
            if (participants[i] == participant) {
                return true;
            }
        }
        return false;
    }

    function burn(uint256 amount) public override {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        uint256 feeAmount = (amount * feePercent) / 100; // 5% fees
        uint256 lotteryFee = feeAmount / 2; // 50% des frais pour la loterie
        lotteryPool += lotteryFee;

        uint256 burnAmount = amount - feeAmount; // Montant à brûler après frais

        _burn(msg.sender, burnAmount); // Brûler les tokens
        if (!isParticipant(msg.sender)) {
            participants.push(msg.sender);
        }
    }

    function getParticipantsCount() public view returns (uint256) {
        return participants.length;
    }

    // Lancer la loterie via Chainlink VRF
    function requestRandomWinner() public returns (bytes32 requestId) {
        require(lotteryPool > 0, "Lottery pool is empty");
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        return requestRandomness(keyHash, fee);
    }

    // Attribution du gagnant via VRF
    function fulfillRandomness(
        bytes32 requestId,
        uint256 randomness
    ) internal override {
        require(participants.length > 0, "No participants in the lottery");
        uint256 winnerIndex = randomness % participants.length;
        recentWinner = participants[winnerIndex];
        payable(recentWinner).transfer(lotteryPool); // Transférer le pool au gagnant
        lotteryPool = 0; // Réinitialiser le pool
        delete participants; // Réinitialiser les participants
    }
}
