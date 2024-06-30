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
import "forge-std/console.sol";

contract RewardsDepositor is Test {
    IRewardsController public constant REWARDS_CONTROLLER =
        IRewardsController(0x91Ac2FfF8CBeF5859eAA6DdA661feBd533cD3780);

    ILoopStrategy public immutable strategy;
    IPool public immutable pool;
    IRewardsController public immutable rewardsController;
    IERC20 public immutable rewardToken;
    IERC20 public immutable supplyToken;
    IERC20 public immutable strategyUnderlying;

    address[] public actors;

    uint256 public counter;

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

    function deposit(uint256 userIndex, uint256 amount, uint8 timeToPass)
        public
    {
        userIndex = bound(userIndex, 0, actors.length - 1);
        amount = bound(amount, 1 ether, 3 ether);
        timeToPass = uint8(bound(uint256(timeToPass), 0, 100_000_000));

        address user = actors[userIndex];

        deal(address(supplyToken), user, amount);
        deal(address(strategyUnderlying), user, amount);

        vm.startPrank(user);

        strategyUnderlying.approve(address(strategy), amount);

        try strategy.deposit(amount, user) returns (uint256 shares) {
            supplyToken.approve(address(pool), shares);
            pool.deposit(address(supplyToken), shares, user, 0);
        } catch {
            console.log("Strategy deposit failed");
        }

        vm.stopPrank();

        _validateRewards();

        vm.warp(block.timestamp + timeToPass);
    }

    function withdraw(uint256 userIndex, uint256 amount, uint8 timeToPass)
        public
    {
        timeToPass = uint8(bound(uint256(timeToPass), 0, 100_000_000));
        userIndex = bound(userIndex, 0, actors.length - 1);
        address user = actors[userIndex];

        if (strategy.balanceOf(user) == 0) {
            return;
        }

        amount = bound(amount, 1, strategy.balanceOf(user));

        vm.startPrank(user);

        try strategy.redeem(amount, user, user) {
            pool.withdraw(address(supplyToken), amount, user);
        } catch {
            console.log("Strategy redeem failed");
        }

        vm.stopPrank();

        _validateRewards();

        vm.warp(block.timestamp + timeToPass);
    }

    function transfer(
        uint256 fromUserIndex,
        uint256 toUserIndex,
        uint256 amount,
        uint8 timeToPass
    ) public {
        fromUserIndex = bound(fromUserIndex, 0, actors.length - 1);
        toUserIndex = bound(toUserIndex, 0, actors.length - 1);
        timeToPass = uint8(bound(uint256(timeToPass), 0, 100_000_000));

        address fromUser = actors[fromUserIndex];
        address toUser = actors[toUserIndex];

        if (strategy.balanceOf(fromUser) == 0) {
            return;
        }

        amount = bound(amount, 1, strategy.balanceOf(fromUser));

        vm.startPrank(fromUser);
        strategy.transfer(toUser, amount);
        IERC20(_getSTokenAddress(address(supplyToken))).transfer(toUser, amount);
        vm.stopPrank();

        _validateRewards();

        vm.warp(block.timestamp + timeToPass);
    }

    function _validateRewards() internal {
        address sSupplyTokenAddress = _getSTokenAddress(address(supplyToken));

        assertEq(
            _getUserRewards(address(strategy), actors[0]),
            _getUserRewards(sSupplyTokenAddress, actors[0]),
            "Alice rewards mismatch"
        );

        assertEq(
            _getUserRewards(address(strategy), actors[1]),
            _getUserRewards(sSupplyTokenAddress, actors[1]),
            "Bob rewards mismatch"
        );

        assertEq(
            _getUserRewards(address(strategy), actors[2]),
            _getUserRewards(sSupplyTokenAddress, actors[2]),
            "Charlie rewards mismatch"
        );
    }

    function _getUserRewards(address asset, address user)
        internal
        view
        returns (uint256)
    {
        address[] memory assets = new address[](1);
        assets[0] = asset;

        return REWARDS_CONTROLLER.getUserRewards(
            assets, user, address(rewardToken)
        );
    }

    function _getSTokenAddress(address reserve) internal returns (address) {
        DataTypes.ReserveData memory reserveData = pool.getReserveData(reserve);
        return reserveData.aTokenAddress;
    }
}
