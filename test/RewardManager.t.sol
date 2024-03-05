// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager, TroveManagerOperation} from "../src/interfaces/core/ITroveManager.sol";
import {IMultiCollateralHintHelpers} from "../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import {SatoshiMath} from "../src/dependencies/SatoshiMath.sol";
import {DeployBase, LocalVars} from "./utils/DeployBase.t.sol";
import {HintLib} from "./utils/HintLib.sol";
import {
    DEPLOYER, OWNER, GAS_COMPENSATION, TestConfig, REWARD_MANAGER, FEE_RECEIVER, _1_MILLION
} from "./TestConfig.sol";
import {TroveBase} from "./utils/TroveBase.t.sol";
import {Events} from "./utils/Events.sol";
import {RoundData} from "../src/mocks/OracleMock.sol";
import {INTEREST_RATE_IN_BPS} from "./TestConfig.sol";
import {IRewardManager} from "../src/interfaces/core/IRewardManager.sol";

contract RewardManagerTest is Test, DeployBase, TroveBase, TestConfig, Events {
    using Math for uint256;

    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;
    address user1;
    address user2;
    address user3;
    address user4;
    uint256 maxFeePercentage = 0.05e18; // 5%

    function setUp() public override {
        super.setUp();

        // testing user
        user1 = vm.addr(1);
        user2 = vm.addr(2);
        user3 = vm.addr(3);
        user4 = vm.addr(4);

        // setup contracts and deploy one instance
        (sortedTrovesBeaconProxy, troveManagerBeaconProxy) = _deploySetupAndInstance(
            DEPLOYER, OWNER, ORACLE_MOCK_DECIMALS, ORACLE_MOCK_VERSION, initRoundData, collateralMock, deploymentParams
        );

        // deploy hint helper contract
        hintHelpers = IMultiCollateralHintHelpers(_deployHintHelpers(DEPLOYER));
    }

    // utils
    function _openTrove(address caller, uint256 collateralAmt, uint256 debtAmt) internal {
        TroveBase.openTrove(
            borrowerOperationsProxy,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            GAS_COMPENSATION,
            caller,
            caller,
            collateralMock,
            collateralAmt,
            debtAmt,
            maxFeePercentage
        );
    }

    function _provideToSP(address caller, uint256 amount) internal {
        TroveBase.provideToSP(stabilityPoolProxy, caller, amount);
    }

    function _withdrawFromSP(address caller, uint256 amount) internal {
        TroveBase.withdrawFromSP(stabilityPoolProxy, caller, amount);
    }

    function _updateRoundData(RoundData memory data) internal {
        TroveBase.updateRoundData(oracleMockAddr, DEPLOYER, data);
    }

    function _claimCollateralGains(address caller) internal {
        vm.startPrank(caller);
        uint256[] memory collateralIndexes = new uint256[](1);
        collateralIndexes[0] = 0;
        stabilityPoolProxy.claimCollateralGains(caller, collateralIndexes);
        vm.stopPrank();
    }

    function _troveClaimReward(address caller) internal returns (uint256 amount) {
        vm.prank(caller);
        amount = troveManagerBeaconProxy.claimReward(caller);
    }

    function _stakeOSHIToRewardManager(address caller, uint256 amount, IRewardManager.LockDuration lock) internal {
        vm.startPrank(caller);
        oshiToken.approve(address(rewardManager), amount);
        rewardManager.stake(amount, lock);
        vm.stopPrank();
    }


    function test_AccrueInterst2TroveCorrect() public {
        // open a trove
        _openTrove(user1, 1e18, 1000e18);
        _openTrove(user2, 1e18, 1000e18);
        (uint256 user1CollBefore, uint256 user1DebtBefore) = troveManagerBeaconProxy.getTroveCollAndDebt(user1);
        (uint256 user2CollBefore, uint256 user2DebtBefore) = troveManagerBeaconProxy.getTroveCollAndDebt(user2);

        // 365 days later
        vm.warp(block.timestamp + 365 days);

        (uint256 user1CollAfter, uint256 user1DebtAfter) = troveManagerBeaconProxy.getTroveCollAndDebt(user1);
        (uint256 user2CollAfter, uint256 user2DebtAfter) = troveManagerBeaconProxy.getTroveCollAndDebt(user2);
        assertEq(user1CollAfter, user1CollBefore);
        assertEq(user2CollAfter, user2CollBefore);

        // check the debt
        uint256 expectedDebt = (user1DebtBefore + user2DebtBefore) * (10000 + INTEREST_RATE_IN_BPS) / 10000;
        uint256 delta = SatoshiMath._getAbsoluteDifference(expectedDebt, user1DebtAfter + user2DebtAfter);
        assert(delta < 1000);
    }

    function test_OneTimeBorrowFeeIncreaseF_SAT() public {
        _openTrove(user1, 1e18, 1000e18);
        // after 5 years
        vm.warp(block.timestamp + 365 days * 5);
        _troveClaimReward(user1);
        uint256 expectedOSHIAmount = 20 * _1_MILLION;
        assertApproxEqAbs(oshiToken.balanceOf(user1), expectedOSHIAmount, 1e10);
        assertEq(debtToken.balanceOf(address(rewardManager)), 5e18);
        assertEq(rewardManager.getPendingSATGain(user1), 0);
        assertEq(rewardManager.satForFeeReceiver(), 5e18);
    }

    function test_StakeOSHIToRM() public {
        _openTrove(user1, 1e18, 1000e18);
        vm.warp(block.timestamp + 10 days);
        uint256 amount = _troveClaimReward(user1);
        _stakeOSHIToRewardManager(user1, amount, IRewardManager.LockDuration.THREE);
    }
}
