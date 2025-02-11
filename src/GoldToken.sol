// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@chainlink/src/v0.8/vrf/VRFConsumerBase.sol";
import "forge-std/console.sol";

import {VRFConsumerBaseV2Plus} from "@chainlink/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract GoldToken is ERC20, ERC20Burnable, ERC20Permit, VRFConsumerBaseV2Plus {
    uint256 s_subscriptionId;
    address vrfCoordinator = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
    bytes32 s_keyHash =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint32 callbackGasLimit = 40000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;

    uint256 public feePercent = 5;
    uint256 public lotteryPool;
    address public recentWinner;

    bytes32 internal keyHash;
    uint256 internal fee;
    address[] private participants;

    constructor(
        uint256 subscriptionId
    )
        ERC20("GoldToken", "GT")
        ERC20Permit("GoldToken")
        VRFConsumerBaseV2Plus(vrfCoordinator)
    {
        s_subscriptionId = subscriptionId;
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
    function requestRandomWinner() public returns (uint256 requestId) {
        require(lotteryPool > 0, "Lottery pool is empty");
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    // Attribution du gagnant via VRF
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        require(participants.length > 0, "No participants in the lottery");
        uint256 winnerIndex = randomWords[0] % participants.length;
        recentWinner = participants[winnerIndex];
        payable(recentWinner).transfer(lotteryPool); // Transférer le pool au gagnant
        lotteryPool = 0; // Réinitialiser le pool
        delete participants; // Réinitialiser les participants
    }
}
