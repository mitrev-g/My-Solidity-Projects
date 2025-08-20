// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {Crowdfunding} from "../src/Crowdfunding.sol";
import {console} from "forge-std/console.sol";

contract CrowfundingTest is Test {
    Crowdfunding public cf;
    address public Alice;
    address public Bob;
    address public Charlie;

    function setUp() public {
        cf = new Crowdfunding();
        Alice = makeAddr("Alice");
        Bob = makeAddr("Bob");
        Charlie = makeAddr("Charlie");
        vm.deal(Bob, 10e18);
        vm.deal(Charlie, 20e18);
    }

    function test_createCampaign() public {
        vm.prank(Alice);
        cf.createCampaign(5e18, block.timestamp + 7 days);
        assert(cf.getNumberOfCampaigns() == 1);
    }

    function test_fail_campaign_less_than_7_days() public {
        vm.prank(Alice);
        vm.expectRevert("DeadlineLessThan7Days()");

        cf.createCampaign(5e18, block.timestamp + 2 days);
    }

    function test_closeCampaign() public {
        vm.startPrank(Alice);
        cf.createCampaign(100, block.timestamp + 7 days);
        cf.closeCampaign(cf.nextCampaignId() - 1);

        vm.stopPrank();
        assertEq(cf.isCampaignActive(0), false);
        assertEq(cf.getCampaign(0).isOpen, false);
    }

    function test_fail_closeCampaignNotExisting(uint256 randomCampaign) public {
        test_createCampaign();
        randomCampaign = bound(randomCampaign, 1, 1000);
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.prank(Alice);
        vm.expectRevert("CampaignDoesNotExist()");
        cf.closeCampaign(campaignId + randomCampaign);
    }

    function test_fail_closeCampaignNotCreator() public {
        test_createCampaign();
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.prank(Bob);
        vm.expectRevert("MsgSenderNotCreator()");
        cf.closeCampaign(campaignId);
    }

    function test_fail_closeCampaignAlreadyClosed() public {
        test_createCampaign();
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.prank(Alice);
        cf.closeCampaign(campaignId);
        vm.prank(Alice);
        vm.expectRevert("CampaignIsNotOpen()");
        cf.closeCampaign(campaignId);
    }

    function test_openCampaign() public {
        test_createCampaign();
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.startPrank(Alice);
        cf.closeCampaign(campaignId);
        cf.openCampaign(campaignId);
        assertEq(cf.isCampaignActive(campaignId), true);
    }

    function test_OpenNonExistentCampaign(uint256 campaignId) public {
        vm.prank(Alice);
        vm.expectRevert("CampaignDoesNotExist()");
        cf.openCampaign(campaignId);
    }

    function test_onlyCreatorCanOpenCampaign() public {
        test_createCampaign();
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.prank(Bob);
        vm.expectRevert("MsgSenderNotCreator()");
        cf.openCampaign(campaignId);
    }

    function test_openOnlyClosedCampaign() public {
        test_createCampaign();
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.prank(Alice);
        vm.expectRevert("CampaignIsOpen()");
        cf.openCampaign(campaignId);
    }

    function test_getAmountCollected() public {
        test_createCampaign();
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.prank(Bob);
        cf.contribute{value: 3e18}(campaignId);
        vm.prank(Charlie);
        cf.contribute{value: 2e18}(campaignId);
        assertEq(cf.getAmountCollected(campaignId), 5e18);
    }

    function test_withdraw() public {
        test_createCampaign();
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.prank(Bob);
        cf.contribute{value: 3e18}(campaignId);
        vm.prank(Charlie);
        cf.contribute{value: 2e18}(campaignId);
        assertEq(cf.isGoalReached(campaignId), true);

        vm.warp(8 days);
        vm.prank(Alice);
        cf.withdraw(campaignId);
        assertEq(cf.getAmountCollected(campaignId), 0);
    }

    function test_fail_withdrawCampaignNotExisting(uint256 randomCampaign) public {
        vm.prank(Alice);
        vm.expectRevert("CampaignDoesNotExist()");
        cf.withdraw(randomCampaign);
    }

    function test_withdrawOnlyCreator() public {
        test_createCampaign();
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.prank(Bob);
        cf.contribute{value: 3e18}(campaignId);
        vm.prank(Charlie);
        cf.contribute{value: 2e18}(campaignId);
        assertEq(cf.isGoalReached(campaignId), true);

        vm.warp(8 days);
        vm.prank(Bob);
        vm.expectRevert("MsgSenderNotCreator()");
        cf.withdraw(campaignId);
    }

    function test_fail_withdrawCampaignClosed() public {
        test_createCampaign();
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.prank(Alice);
        cf.closeCampaign(campaignId);
        vm.prank(Alice);
        vm.expectRevert("CampaignIsNotOpen()");
        cf.withdraw(campaignId);
    }

    function test_fail_withdrawBeforeDeadline() public {
        test_createCampaign();
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.prank(Bob);
        cf.contribute{value: 3e18}(campaignId);
        vm.prank(Charlie);
        cf.contribute{value: 2e18}(campaignId);
        assertEq(cf.isGoalReached(campaignId), true);

        vm.warp(6 days);
        vm.prank(Alice);
        vm.expectRevert("CampaignDeadLineIsNotOver()");
        cf.withdraw(campaignId);
    }

    function test_fail_withdrawTargetNotReached() public {
        test_createCampaign();
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.prank(Bob);
        cf.contribute{value: 1e18}(campaignId);
        vm.prank(Charlie);
        cf.contribute{value: 2e18}(campaignId);
        assertEq(cf.isGoalReached(campaignId), false);

        vm.warp(8 days);
        vm.prank(Alice);
        vm.expectRevert("TargetNotReached()");
        cf.withdraw(campaignId);
    }

    function test_contribute() public {
        vm.prank(Alice);
        cf.createCampaign(100, block.timestamp + 7 days);
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.prank(Bob);
        cf.contribute{value: 1e18}(campaignId);

        assertEq(cf.getAmountContributed(campaignId, Bob), 1e18);
    }

    function test_contributeZero() public {
        test_createCampaign();
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.startPrank(Bob);
        vm.expectRevert("ContributionCanNotBeZero()");
        cf.contribute{value: 0}(campaignId);
    }

    function test_contributeToNonExistentCampaign(uint256 campaignId) public {
        vm.startPrank(Bob);
        vm.expectRevert("CampaignDoesNotExist()");
        cf.contribute{value: 1e18}(campaignId);
    }

    function test_fail_contributeToClosedCapaign() public {
        test_createCampaign();
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.prank(Alice);
        cf.closeCampaign(campaignId);
        vm.prank(Bob);
        vm.expectRevert("CampaignIsNotOpen()");
        cf.contribute{value: 1e18}(campaignId);
    }

    function test_contributeToEndedCampaign() public {
        test_createCampaign();
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.warp(8 days);
        vm.prank(Bob);
        vm.expectRevert("CampaignDeadLineIsOver()");
        cf.contribute{value: 1e18}(campaignId);
    }

    function test_refundContribution() public {
        vm.prank(Alice);
        cf.createCampaign(10e18, block.timestamp + 7 days);
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.prank(Bob);
        cf.contribute{value: 5e18}(campaignId);
        uint256 BobBalanceBefore = address(Bob).balance;
        assertEq(BobBalanceBefore, 5e18);

        vm.warp(8 days);
        vm.prank(Bob);
        cf.refundContribution(campaignId);
        uint256 BobBalanceAfter = address(Bob).balance;
        assertEq(BobBalanceAfter, 10e18);

        assertEq(cf.getAmountContributed(campaignId, Bob), 0);
    }

    function test_refundFromNonExistentCampaign(uint256 id) public {
        vm.prank(Bob);
        vm.expectRevert("CampaignDoesNotExist()");
        cf.refundContribution(id);
    }

    function test_refundWithNoContribution() public {
        test_createCampaign();
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.prank(Bob);
        vm.expectRevert("MsgSenderDidNotContribute()");
        cf.refundContribution(campaignId);
    }

    function test_RefundAfterTargetReached() public {
        vm.prank(Alice);
        cf.createCampaign(10e18, block.timestamp + 7 days);
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.prank(Bob);
        cf.contribute{value: 5e18}(campaignId);
        vm.prank(Charlie);
        cf.contribute{value: 6e18}(campaignId);
        vm.warp(8 days);
        assertEq(cf.isGoalReached(campaignId), true);

        vm.prank(Bob);
        vm.expectRevert("TargetReached()");
        cf.refundContribution(campaignId);
    }

    function test_RefundBeforeDeadline() public {
        vm.prank(Alice);
        cf.createCampaign(10e18, block.timestamp + 7 days);
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.prank(Bob);
        cf.contribute{value: 5e18}(campaignId);
        vm.warp(6 days);
        vm.prank(Bob);
        vm.expectRevert("CampaignIsOpen()");
        cf.refundContribution(campaignId);
    }

    function test_refundFromOpenCampaign() public {
        test_createCampaign();
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.prank(Bob);
        cf.contribute{value: 2e18}(campaignId);
        vm.prank(Bob);
        vm.expectRevert("CampaignIsOpen()");
        cf.refundContribution(campaignId);
    }

    function test_hasContributed() public {
        vm.prank(Alice);
        cf.createCampaign(10e18, block.timestamp + 7 days);
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.prank(Bob);
        cf.contribute{value: 5e18}(campaignId);
        assertEq(cf._hasContributed(campaignId, Bob), true);
    }

    function test_numberOfContributors() public {
        test_createCampaign();
        uint256 campaignId = cf.nextCampaignId() - 1;
        vm.prank(Bob);
        cf.contribute{value: 5e18}(campaignId);
        vm.prank(Charlie);
        cf.contribute{value: 6e18}(campaignId);
        vm.prank(Bob);
        cf.contribute{value: 1e18}(campaignId);
        assertEq(cf.getCampaign(campaignId).numberOfContributors, 2);
    }

    function test_getDeadline() public {
        vm.prank(Alice);
        cf.createCampaign(10e18, block.timestamp + 7 days);
        uint256 campaignId = cf.nextCampaignId() - 1;
        assertEq(cf.getDeadline(campaignId), block.timestamp + 7 days);
    }
}
