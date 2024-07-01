// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IPool } from "@aave/contracts/interfaces/IPool.sol";
import { IRewardsController } from
    "@aave-periphery/contracts/rewards/interfaces/IRewardsController.sol";
import { ILoopStrategy } from "../../../src/interfaces/ILoopStrategy.sol";
import { StrategyAssets } from "../../../src/types/DataTypes.sol";
import { DataTypes } from
    "@aave/contracts/protocol/libraries/types/DataTypes.sol";
import { Test } from "forge-std/Test.sol";
import { TestConstants } from "../../config/TestConstants.sol";
import "forge-std/console.sol";

contract RewardsHandler is Test, TestConstants {
    ILoopStrategy public immutable strategy;
    IPool public immutable pool;
    IRewardsController public immutable rewardsController;
    IERC20 public immutable rewardToken;
    IERC20 public immutable supplyToken;
    IERC20 public immutable strategyUnderlying;

    address public sSupplyTokenAddress;
    address[] public actors;

    modifier useActor(uint256 actorIndexSeed) {
        address currentActor =
            actors[bound(actorIndexSeed, 0, actors.length - 1)];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    constructor(
        address _strategy,
        address _pool,
        address _rewardsController,
        address _rewardToken,
        address _supplyToken
    ) {
        strategy = ILoopStrategy(_strategy);
        pool = IPool(_pool);
        rewardsController = IRewardsController(_rewardsController);
        rewardToken = IERC20(_rewardToken);
        supplyToken = IERC20(_supplyToken);

        DataTypes.ReserveData memory reserveData =
            pool.getReserveData(address(supplyToken));
        sSupplyTokenAddress = reserveData.aTokenAddress;

        StrategyAssets memory strategyAssets = strategy.getAssets();
        strategyUnderlying = strategyAssets.underlying;
    }

    function createUsers() public {
        actors.push(makeAddr("alice"));
        actors.push(makeAddr("bob"));
        actors.push(makeAddr("charley"));
    }

    function getActors() public view returns (address[] memory) {
        return actors;
    }

    function deposit(uint256 actorIndex, uint256 amount, uint8 timeToPass)
        public
        useActor(actorIndex)
    {
        amount = bound(amount, 1 ether, 3 ether);
        timeToPass = uint8(bound(uint256(timeToPass), 0, 100_000));

        (, address user,) = vm.readCallers();

        deal(address(supplyToken), user, amount);
        deal(address(strategyUnderlying), user, amount);

        strategyUnderlying.approve(address(strategy), amount);

        // Sometimes deposit fails. In that case we just skip. This is required to make sure test does not revert
        try strategy.deposit(amount, user) returns (uint256 shares) {
            supplyToken.approve(address(pool), shares);
            pool.deposit(address(supplyToken), shares, user, 0);
        } catch {
            console.log("Strategy deposit failed");
        }

        vm.warp(block.timestamp + timeToPass);
    }

    function withdraw(uint256 actorIndex, uint256 amount, uint8 timeToPass)
        public
        useActor(actorIndex)
    {
        timeToPass = uint8(bound(uint256(timeToPass), 0, 100_000));

        (, address user,) = vm.readCallers();

        if (strategy.balanceOf(user) == 0) {
            return;
        }

        amount = bound(amount, 1, strategy.balanceOf(user));

        // Sometimes redeem fails because of small amounts. In that case we just skip
        try strategy.redeem(amount, user, user) {
            pool.withdraw(address(supplyToken), amount, user);
        } catch {
            console.log("Strategy redeem failed");
        }

        vm.warp(block.timestamp + timeToPass);
    }

    function transfer(
        uint256 fromActorIndex,
        uint256 toActorIndex,
        uint256 amount,
        uint8 timeToPass
    ) public useActor(fromActorIndex) {
        toActorIndex = bound(toActorIndex, 0, actors.length - 1);
        timeToPass = uint8(bound(uint256(timeToPass), 0, 100_000));

        (, address fromUser,) = vm.readCallers();
        address toUser = actors[toActorIndex];

        if (strategy.balanceOf(fromUser) == 0) {
            return;
        }

        amount = bound(amount, 1, strategy.balanceOf(fromUser));

        strategy.transfer(toUser, amount);
        IERC20(sSupplyTokenAddress).transfer(toUser, amount);

        vm.warp(block.timestamp + timeToPass);
    }

    function claimAllRewards(
        uint256 fromActorIndex,
        uint256 toActorIndex,
        uint8 timeToPass
    ) external useActor(fromActorIndex) {
        toActorIndex = bound(toActorIndex, 0, actors.length - 1);
        timeToPass = uint8(bound(uint256(timeToPass), 0, 100_000));

        address toUser = actors[toActorIndex];

        address[] memory assets = new address[](1);
        assets[0] = address(strategy);

        (address[] memory rewardsList1, uint256[] memory claimedAmounts1) =
            REWARDS_CONTROLLER.claimAllRewards(assets, toUser);

        assets[0] = sSupplyTokenAddress;
        (address[] memory rewardsList2, uint256[] memory claimedAmounts2) =
            REWARDS_CONTROLLER.claimAllRewards(assets, toUser);

        assertEq(
            rewardsList1.length, rewardsList2.length, "Rewards length mismatch"
        );
        assertEq(
            claimedAmounts1.length,
            claimedAmounts2.length,
            "Claimed amounts length mismatch"
        );

        for (uint256 i = 0; i < rewardsList1.length; i++) {
            assertEq(rewardsList1[i], rewardsList2[i], "Rewards mismatch");
            assertEq(
                claimedAmounts1[i],
                claimedAmounts2[i],
                "Claimed amounts mismatch"
            );
        }

        vm.warp(block.timestamp + timeToPass);
    }
}
