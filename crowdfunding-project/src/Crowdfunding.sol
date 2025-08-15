//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract Crowdfunding {
    ///////////////////////////////////
    ///       CUSTOM ERRORS        ///
    /////////////////////////////////

    error DeadlineLessThan7Days();

    error CampaignDoesNotExist();

    error CampaignIsNotOpen();

    error ContributionCanNotBeZero();

    error CampaignDeadLineIsOver();

    error ContributionFailed();

    error MsgSenderNotCreator();

    error CampaignDeadLineIsNotOver();

    error WithdrawalFailed();

    error MsgSenderDidNotContribute();

    error RefundFailed();

    error CampaignIsOpen();

    error TargetNotReached();

    error TargetReached();

    ///////////////////////////////////
    ///       EVENTS               ///
    /////////////////////////////////

    event CampaignCreated(uint256 indexed id, address indexed creator, uint256 target, uint256 deadline);

    event ContributionMade(uint256 indexed id, address indexed contributor, uint256 amountContributed);

    event CampaignClosed(uint256 indexed id);

    event FundsWithdrawn(uint256 indexed id, address indexed receiver, uint256 amount);

    event RefundIssued(uint256 indexed id, address indexed receiver, uint256 amount);

    ///////////////////////////////////
    ///     STORAGE VARIABLES      ///
    /////////////////////////////////

    struct Campaign {
        address creator;
        uint256 target;
        uint256 deadline;
        uint256 amountCollected;
        uint256 numberOfContributors;
        uint256 campaignId;
        bool isOpen;
    }

    uint256 public nextCampaignId = 0;

    mapping(uint256 id => Campaign) public campaigns;

    mapping(uint256 id => mapping(address user => uint256 amount)) public contributions;

    ///////////////////////////////////
    ///          MODIFIERS         ///
    /////////////////////////////////

    modifier onlyCreator(uint256 id) {
        if (msg.sender != campaigns[id].creator) {
            revert MsgSenderNotCreator();
        }
        _;
    }

    modifier campaignExists(uint256 id) {
        if (campaigns[id].creator == address(0)) {
            revert CampaignDoesNotExist();
        }
        _;
    }

    modifier campaignIsOpen(uint256 id) {
        if (campaigns[id].isOpen == false) {
            revert CampaignIsNotOpen();
        }
        _;
    }

    modifier campaignIsClosed(uint256 id) {
        if (campaigns[id].isOpen == true) {
            revert CampaignIsOpen();
        }
        _;
    }

    modifier campaignIsNotOver(uint256 id) {
        if (block.timestamp > campaigns[id].deadline) {
            revert CampaignDeadLineIsOver();
        }
        _;
    }

    modifier campaignIsOver(uint256 id) {
        if (block.timestamp < campaigns[id].deadline) {
            revert CampaignDeadLineIsNotOver();
        }
        _;
    }

    modifier hasContributed(uint256 id) {
        if (contributions[id][msg.sender] == 0) {
            revert MsgSenderDidNotContribute();
        }
        _;
    }

    modifier targetReached(uint256 id) {
        if (campaigns[id].amountCollected < campaigns[id].target) {
            revert TargetNotReached();
        }
        _;
    }

    modifier targetNotReached(uint256 id) {
        if (campaigns[id].amountCollected >= campaigns[id].target) {
            revert TargetReached();
        }
        _;
    }

    ///////////////////////////////////
    /// CAMPAIGN CREATOR FUNCTIONS ///
    /////////////////////////////////

    /**
     * @dev Create a campaign
     * @param _target - Target amount
     * @param _deadline - Deadline of the campaign
     */
    function createCampaign(uint256 _target, uint256 _deadline) public {
        if (_deadline < block.timestamp + 7 days) {
            revert DeadlineLessThan7Days();
        }

        Campaign memory campaign;

        campaign.creator = msg.sender;
        campaign.target = _target;
        campaign.deadline = _deadline;
        campaign.amountCollected = 0;
        campaign.numberOfContributors = 0;
        campaign.isOpen = true;
        campaign.campaignId = nextCampaignId;

        campaigns[nextCampaignId] = campaign;
        nextCampaignId++;
        emit CampaignCreated(campaign.campaignId, msg.sender, _target, _deadline);
    }

    /**
     *
     * @param id ID of the Campaign to be closed
     */
    function closeCampaign(uint256 id) public onlyCreator(id) campaignExists(id) campaignIsOpen(id) {
        campaigns[id].isOpen = false;
        emit CampaignClosed(id);
    }

    /**
     *
     * @param id ID of the campaign
     */
    function withdraw(uint256 id)
        public
        onlyCreator(id)
        campaignExists(id)
        campaignIsOpen(id)
        campaignIsOver(id)
        targetReached(id)
    {
        campaigns[id].isOpen = false;

        uint256 amount = campaigns[id].amountCollected;
        campaigns[id].amountCollected = 0;
        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert WithdrawalFailed();
        }
        emit FundsWithdrawn(id, msg.sender, amount);
    }

    ///////////////////////////////////
    ///    CONTRIBUTOR FUNCTIONS   ///
    /////////////////////////////////

    /**
     *
     * @param id ID of the campaign which receives the contribution
     */
    function contribute(uint256 id) public payable campaignExists(id) campaignIsOpen(id) campaignIsNotOver(id) {
        if (msg.value == 0) {
            revert ContributionCanNotBeZero();
        }
        if (contributions[id][msg.sender] == 0) {
            campaigns[id].numberOfContributors++;
        }

        campaigns[id].amountCollected += msg.value;
        contributions[id][msg.sender] += msg.value;

        emit ContributionMade(id, msg.sender, msg.value);
    }

    /**
     *
     * @param id ID of the campaign the user wants to refund from
     */
    function refundContribution(uint256 id)
        public
        hasContributed(id)
        campaignIsClosed(id)
        campaignIsOver(id)
        targetNotReached(id)
    {
        uint256 amount = getAmountContributed(id, msg.sender);

        contributions[id][msg.sender] = 0;
        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert RefundFailed();
        }
        emit RefundIssued(id, msg.sender, amount);
    }

    ///////////////////////////////////
    ///       VIEW FUNCTIONS       ///
    /////////////////////////////////

    /**
     *
     * @param id - ID of the campaign
     * @param contributor - Address of the contributor
     */
    function _hasContributed(uint256 id, address contributor) internal view returns (bool) {
        return contributions[id][contributor] > 0;
    }

    /**
     *
     * @param id - ID of the campaign
     */
    function getDeadline(uint256 id) public view returns (uint256) {
        return campaigns[id].deadline;
    }
    /**
     *
     * @param id - ID of the campaign
     */

    function isGoalReached(uint256 id) public view returns (bool) {
        return campaigns[id].amountCollected >= campaigns[id].target;
    }
    /**
     *
     * @param id - ID of the campaign
     */

    function isCampaignActive(uint256 id) public view returns (bool) {
        return campaigns[id].isOpen;
    }
    /**
     *
     * @param id - ID of the campaign
     */

    function getAmountCollected(uint256 id) public view returns (uint256) {
        return campaigns[id].amountCollected;
    }
    /**
     *
     * @param id - ID of the campaign
     * @param contributor - Address of the contributor
     */

    function getAmountContributed(uint256 id, address contributor) public view returns (uint256) {
        return contributions[id][contributor];
    }
    /**
     *
     * @param id - ID of the campaign
     */

    function getCampaign(uint256 id) public view returns (Campaign memory) {
        return campaigns[id];
    }
    /**
     *
     * @dev Returns the number of campaigns
     */

    function getNumberOfCampaigns() public view returns (uint256) {
        return nextCampaignId;
    }
}
