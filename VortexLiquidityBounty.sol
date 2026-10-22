// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract VortexLiquidityBounty {
    enum BountyStatus { Open, Solved, Canceled }

    struct BountyTask {
        string taskTitle;
        uint256 rewardAmount;
        address payable poster;
        address payable claimWinner;
        uint256 deadline;
        BountyStatus status;
        bytes32 solutionReviewHash;
    }

    address payable public immutable bountyMaster;
    string public protocolBadge;
    uint256 public bountyCount;
    uint256 public totalBountyEscrow;

    mapping(uint256 => BountyTask) public bounties;

    event BountyPosted(uint256 indexed bountyId, string title, uint256 reward, uint256 deadline);
    event BountyFundRefilled(uint256 indexed bountyId, uint256 addedFunds);
    event SolutionLogged(uint256 indexed bountyId, bytes32 reviewHash);
    event BountySettled(uint256 indexed bountyId, address indexed winner, uint256 payout);
    event BountyAborted(uint256 indexed bountyId, uint256 refundedAmount);
    event DeadlineExtended(uint256 indexed bountyId, uint256 newDeadline);
    event ProtocolBadgeUpdated(string newBadge);
    event ProtocolTreasurySwept(address indexed recipient, uint256 amount);

    modifier onlyMaster() {
        require(msg.sender == bountyMaster, "VortexBounty: Caller is not Bounty Master");
        _;
    }

    constructor() {
        bountyMaster = payable(msg.sender);
        protocolBadge = "Vortex Base Bounty Engine v1";
    }

    // 1. Создание задачи с депозитом награды в ETH
    function postBountyTask(
        string calldata taskTitle,
        uint256 durationSeconds
    ) external payable returns (uint256) {
        require(msg.value > 0, "VortexBounty: Reward must be positive");
        require(bytes(taskTitle).length > 0, "VortexBounty: Empty title");
        require(durationSeconds >= 60, "VortexBounty: Min duration 60s");

        bountyCount++;
        bounties[bountyCount] = BountyTask({
            taskTitle: taskTitle,
            rewardAmount: msg.value,
            poster: payable(msg.sender),
            claimWinner: payable(address(0)),
            deadline: block.timestamp + durationSeconds,
            status: BountyStatus.Open,
            solutionReviewHash: bytes32(0)
        });

        totalBountyEscrow += msg.value;
        emit BountyPosted(bountyCount, taskTitle, msg.value, block.timestamp + durationSeconds);
        return bountyCount;
    }

    // 2. Дополнительное пополнение призового фонда задачи
    function topUpBountyReward(uint256 bountyId) external payable {
        BountyTask storage b = bounties[bountyId];
        require(bountyId > 0 && bountyId <= bountyCount, "VortexBounty: Invalid ID");
        require(b.status == BountyStatus.Open, "VortexBounty: Bounty not open");
        require(msg.value > 0, "VortexBounty: Zero deposit rejected");

        b.rewardAmount += msg.value;
        totalBountyEscrow += msg.value;

        emit BountyFundRefilled(bountyId, msg.value);
    }

    // 3. Фиксация хэша решения задачи
    function submitSolutionReview(uint256 bountyId, bytes32 reviewHash) external {
        BountyTask storage b = bounties[bountyId];
        require(bountyId > 0 && bountyId <= bountyCount, "VortexBounty: Invalid ID");
        require(b.status == BountyStatus.Open, "VortexBounty: Bounty not open");
        require(reviewHash != bytes32(0), "VortexBounty: Invalid hash");

        b.solutionReviewHash = reviewHash;
        emit SolutionLogged(bountyId, reviewHash);
    }

    // 4. Утверждение решения и выплата награды исполнителю
    function approveAndPayWinner(uint256 bountyId, address payable winner) external {
        BountyTask storage b = bounties[bountyId];
        require(b.poster == msg.sender, "VortexBounty: Only poster can approve");
        require(b.status == BountyStatus.Open, "VortexBounty: Not open for payout");
        require(winner != address(0), "VortexBounty: Zero address winner");

        b.status = BountyStatus.Solved;
        b.claimWinner = winner;
        uint256 payout = b.rewardAmount;
        b.rewardAmount = 0;
        totalBountyEscrow -= payout;

        (bool sent, ) = winner.call{value: payout}("");
        require(sent, "VortexBounty: Payout transfer failed");

        emit BountySettled(bountyId, winner, payout);
    }

    // 5. Отмена задачи и возврат средств автору
    function cancelBounty(uint256 bountyId) external {
        BountyTask storage b = bounties[bountyId];
        require(b.poster == msg.sender, "VortexBounty: Only poster can cancel");
        require(b.status == BountyStatus.Open, "VortexBounty: Cannot cancel");

        b.status = BountyStatus.Canceled;
        uint256 refund = b.rewardAmount;
        b.rewardAmount = 0;
        totalBountyEscrow -= refund;

        (bool sent, ) = b.poster.call{value: refund}("");
        require(sent, "VortexBounty: Refund transfer failed");

        emit BountyAborted(bountyId, refund);
    }

    // 6. Продление дедлайна задачи
    function extendBountyDeadline(uint256 bountyId, uint256 extraSeconds) external {
        BountyTask storage b = bounties[bountyId];
        require(b.poster == msg.sender, "VortexBounty: Only poster can extend");
        require(b.status == BountyStatus.Open, "VortexBounty: Not open");
        require(extraSeconds > 0, "VortexBounty: Invalid extra time");

        b.deadline += extraSeconds;
        emit DeadlineExtended(bountyId, b.deadline);
    }

    // 7. Обновление мета-бейджа платформы
    function setProtocolBadge(string calldata newBadge) external onlyMaster {
        require(bytes(newBadge).length > 0, "VortexBounty: Empty badge");
        protocolBadge = newBadge;
        emit ProtocolBadgeUpdated(newBadge);
    }

    // 8. Аварийный вывод остатка казны контракта
    function emergencyDrainSweep() external onlyMaster {
        uint256 surplus = address(this).balance > totalBountyEscrow ? address(this).balance - totalBountyEscrow : 0;
        if (surplus == 0 && address(this).balance > 0 && totalBountyEscrow == 0) {
            surplus = address(this).balance;
        }
        require(surplus > 0, "VortexBounty: Zero funds available");

        (bool sent, ) = bountyMaster.call{value: surplus}("");
        require(sent, "VortexBounty: Sweep failed");

        emit ProtocolTreasurySwept(bountyMaster, surplus);
    }

    // Чтение информации о задаче
    function getBountyDetails(uint256 bountyId) external view returns (
        string memory taskTitle,
        uint256 rewardAmount,
        address poster,
        address claimWinner,
        uint256 deadline,
        BountyStatus status,
        bytes32 solutionReviewHash
    ) {
        BountyTask memory b = bounties[bountyId];
        return (b.taskTitle, b.rewardAmount, b.poster, b.claimWinner, b.deadline, b.status, b.solutionReviewHash);
    }
}