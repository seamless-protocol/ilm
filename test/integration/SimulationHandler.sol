// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { LoopStrategy, ILoopStrategy } from "../../src/LoopStrategy.sol";
import { USDWadRayMath } from "../../src/libraries/math/USDWadRayMath.sol";

/// @notice Helper contract used from SimulationTest to run transactions on the pool and capture data
/// @notice On each transaction parameters before and after are captured and checked for basic correctness
contract SimulationHandler is Test {
    LoopStrategy public strategy;
    uint256 public numUsers;

    uint256 public minDeposit;
    uint256 public maxDeposit;

    string public constant json = "json";
    string public jsonPath;
    string public jsonOut;
    uint256 public dataId;

    /// @dev data obtained from the LoopStrategy contract
    struct StrategyData {
        uint256 collateral;
        uint256 debt;
        uint256 collateralRatio;
        uint256 equity;
        uint256 equityUSD;
        uint256 totalSupply;
        bool rebalanceNeeded;
        // userData
        uint256 userShares;
        uint256 userBalance;
    }

    /// @dev data saved for the last user deposit
    struct DepositData {
        uint256 timestamp;
        uint256 amount;
    }

    mapping(address user => DepositData data) public lastDeposit;

    constructor(
        LoopStrategy _strategy,
        uint256 _numUsers,
        uint256 _startUnderlyingAmount,
        uint256 _minDeposit,
        uint256 _maxDeposit,
        string memory _jsonPath
    ) {
        strategy = _strategy;
        numUsers = _numUsers;
        minDeposit = _minDeposit;
        maxDeposit = _maxDeposit;
        jsonPath = _jsonPath;

        address underlying = address(strategy.getAssets().underlying);
        for (uint256 i = 1; i <= numUsers; i++) {
            deal(underlying, vm.addr(i), _startUnderlyingAmount);
        }
    }

    function nextAction(uint256 seed) public {
        uint256 userId = bound(seed, 1, numUsers);
        address user = vm.addr(userId);

        uint256 userShares = strategy.balanceOf(user);

        if (userShares > 0) {
            redeem(seed, userId);
        } else {
            deposit(seed, userId);
        }
    }

    /// @dev deposits assets to the strategy
    /// @param seed random seed used to generate user and amount for deposit
    function deposit(uint256 seed, uint256 userId) public {
        address user = vm.addr(userId);

        StrategyData memory dataBefore = _getStrategyData(user);

        vm.startPrank(user);
        uint256 amount = bound(seed, minDeposit, maxDeposit);

        strategy.getAssets().underlying.approve(address(strategy), amount);

        uint256 previewDeposit = strategy.previewDeposit(amount);
        uint256 shares = strategy.deposit(amount, user);
        vm.stopPrank();

        StrategyData memory dataAfter = _getStrategyData(user);

        _checkDepositData(dataBefore, dataAfter);

        _addDepositDataPoint(
            user, userId, amount, shares, previewDeposit, dataBefore, dataAfter
        );

        lastDeposit[user].timestamp = block.timestamp;
        lastDeposit[user].amount = amount;
    }

    /// @dev redeems assets from the strategy
    /// @param seed random seed used to generate user
    function redeem(uint256 seed, uint256 userId) public {
        address user = vm.addr(userId);

        uint256 userShares = strategy.balanceOf(user);

        if (userShares > 0) {
            StrategyData memory dataBefore = _getStrategyData(user);

            vm.startPrank(user);
            uint256 previewRedeem = strategy.previewRedeem(userShares);
            uint256 assetsReceived = strategy.redeem(userShares, user, user);
            vm.stopPrank();

            StrategyData memory dataAfter = _getStrategyData(user);

            _checkRedeemData(dataBefore, dataAfter);

            _addRedeemDataPoint(
                user,
                userId,
                userShares,
                assetsReceived,
                previewRedeem,
                dataBefore,
                dataAfter
            );
        }
    }

    /// @dev rebalances strategy if collateral ratio is out of bounds
    function rebalance() public {
        if (strategy.rebalanceNeeded()) {
            StrategyData memory dataBefore = _getStrategyData(address(0));

            strategy.rebalance();

            StrategyData memory dataAfter = _getStrategyData(address(0));

            _checkRebalanceData(dataBefore, dataAfter);

            _addRebalanceDataPoint(dataBefore, dataAfter);
        }
    }

    /// @dev captures the current stratgy data, including some user data
    /// @param user address of the user which data is captured
    function _getStrategyData(address user)
        internal
        view
        returns (StrategyData memory)
    {
        return StrategyData({
            collateral: strategy.collateralUSD(),
            debt: strategy.debtUSD(),
            collateralRatio: strategy.currentCollateralRatio(),
            equity: strategy.equity(),
            equityUSD: strategy.equityUSD(),
            totalSupply: strategy.totalSupply(),
            rebalanceNeeded: strategy.rebalanceNeeded(),
            userShares: strategy.balanceOf(user),
            userBalance: strategy.getAssets().underlying.balanceOf(user)
        });
    }

    /// @dev checks if equity after transaction is always greater or equalt to equity before transaction
    /// @param dataBefore strategy data before transaction
    /// @param dataAfter strategy data after transaction
    function _checkEquity(
        StrategyData memory dataBefore,
        StrategyData memory dataAfter
    ) internal {
        if (
            !dataBefore.rebalanceNeeded
                && dataBefore.collateralRatio == dataAfter.collateralRatio
        ) {
            uint256 equityPerShareBefore = 0;
            if (dataBefore.totalSupply > 0) {
                equityPerShareBefore = USDWadRayMath.wadDiv(
                    dataBefore.equity, dataBefore.totalSupply
                );
            }

            uint256 equityPerShareAfter = 0;
            if (strategy.totalSupply() > 0) {
                equityPerShareAfter = USDWadRayMath.wadDiv(
                    dataAfter.equity, dataAfter.totalSupply
                );
            }

            if (equityPerShareAfter != 0) {
                assertGe(equityPerShareAfter, equityPerShareBefore);
            } else {
                assertEq(dataAfter.totalSupply, 0);
            }
        }
    }

    /// @dev checks difference in the strategy data before and after the deposit transaciton
    /// @param dataBefore strategy data before transaction
    /// @param dataAfter strategy data after transaction
    function _checkDepositData(
        StrategyData memory dataBefore,
        StrategyData memory dataAfter
    ) internal {
        assertGe(dataAfter.totalSupply, dataBefore.totalSupply);
        assertGe(dataAfter.collateral, dataBefore.collateral);
        assertGe(dataAfter.debt, dataBefore.debt);
        assertEq(dataAfter.rebalanceNeeded, false);
        _checkEquity(dataBefore, dataAfter);
    }

    /// @dev checks difference in the strategy data before and after the redeem transaciton
    /// @param dataBefore strategy data before transaction
    /// @param dataAfter strategy data after transaction
    function _checkRedeemData(
        StrategyData memory dataBefore,
        StrategyData memory dataAfter
    ) internal {
        assertGe(dataBefore.totalSupply, dataAfter.totalSupply);
        assertGe(dataBefore.collateral, dataAfter.collateral);
        assertGe(dataBefore.debt, dataAfter.debt);
        assertEq(dataAfter.rebalanceNeeded, false);
        _checkEquity(dataBefore, dataAfter);
    }

    function _checkRebalanceData(
        StrategyData memory dataBefore,
        StrategyData memory dataAfter
    ) internal {
        assertEq(dataBefore.totalSupply, dataAfter.totalSupply);
        assertEq(dataBefore.rebalanceNeeded, true);
        assertEq(dataAfter.rebalanceNeeded, false);
    }

    /// @dev saves the current json to the file
    function saveJson() public {
        vm.writeJson(jsonOut, jsonPath);
    }

    /// @dev serializes strategy data to the json object
    /// @param data stragey data
    function _serializeStrategyData(StrategyData memory data)
        internal
        returns (string memory)
    {
        string memory obj = "strategyDataObj";
        vm.serializeUint(obj, "collateral", data.collateral);
        vm.serializeUint(obj, "debt", data.debt);
        vm.serializeUint(obj, "equity", data.equity);
        vm.serializeUint(obj, "equityUSD", data.equityUSD);
        vm.serializeUint(obj, "totalSupply", data.totalSupply);
        vm.serializeBool(obj, "rebalanceNeeded", data.rebalanceNeeded);
        vm.serializeUint(obj, "userShares", data.userShares);
        string memory out =
            vm.serializeUint(obj, "userBalance", data.userBalance);

        return out;
    }

    /// @dev serializes deposit transaction data and adds it to the global json
    /// @param user address of the user
    /// @param userId user id
    /// @param amount amount of underlying tokens
    /// @param received number of received shares
    /// @param previewDeposit expected shares returned by previewDeposit function
    /// @param dataBefore strategy data before transaction
    /// @param dataAfter strategy data after transaction
    function _addDepositDataPoint(
        address user,
        uint256 userId,
        uint256 amount,
        uint256 received,
        uint256 previewDeposit,
        StrategyData memory dataBefore,
        StrategyData memory dataAfter
    ) internal {
        string memory obj = "depositObj";
        vm.serializeUint(obj, "timestamp", block.timestamp);
        vm.serializeUint(
            obj, "ColAssetPrice", _getPrice(strategy.getAssets().underlying)
        );
        vm.serializeUint(
            obj, "DebtAssetPrice", _getPrice(strategy.getAssets().debt)
        );
        vm.serializeUint(obj, "userId", userId);
        vm.serializeAddress(obj, "user", user);
        vm.serializeString(obj, "action", "DEPOSIT");
        vm.serializeUint(obj, "amount", amount);
        vm.serializeUint(obj, "received", received);
        vm.serializeUint(obj, "preview", previewDeposit);
        vm.serializeString(
            obj, "dataBefore", _serializeStrategyData(dataBefore)
        );
        vm.serializeString(obj, "dataAfter", _serializeStrategyData(dataAfter));

        dataId++;
        string memory out = vm.serializeUint(obj, "dataId", dataId);
        jsonOut = vm.serializeString(json, Strings.toString(dataId), out);
    }

    /// @dev serializes redeem transaction data and adds it to the global json
    /// @param user address of the user
    /// @param userId user id
    /// @param amount amount of shares redeemed
    /// @param received number of received assets
    /// @param previewRedeem expected shares returned by previewRedeem function
    /// @param dataBefore strategy data before transaction
    /// @param dataAfter strategy data after transaction
    function _addRedeemDataPoint(
        address user,
        uint256 userId,
        uint256 amount,
        uint256 received,
        uint256 previewRedeem,
        StrategyData memory dataBefore,
        StrategyData memory dataAfter
    ) internal {
        string memory obj = "redeemObj";
        vm.serializeUint(obj, "timestamp", block.timestamp);
        vm.serializeUint(
            obj, "ColAssetPrice", _getPrice(strategy.getAssets().underlying)
        );
        vm.serializeUint(
            obj, "DebtAssetPrice", _getPrice(strategy.getAssets().debt)
        );
        vm.serializeUint(obj, "userId", userId);
        vm.serializeAddress(obj, "user", user);
        vm.serializeString(obj, "action", "REDEEM");
        vm.serializeUint(obj, "amount", amount);
        vm.serializeUint(obj, "received", received);
        vm.serializeUint(obj, "preview", previewRedeem);
        vm.serializeUint(
            obj, "lastDepositTimestamp", lastDeposit[user].timestamp
        );
        vm.serializeUint(obj, "lastDepositAmount", lastDeposit[user].amount);
        vm.serializeString(
            obj, "dataBefore", _serializeStrategyData(dataBefore)
        );
        vm.serializeString(obj, "dataAfter", _serializeStrategyData(dataAfter));

        dataId++;
        string memory out = vm.serializeUint(obj, "dataId", dataId);
        jsonOut = vm.serializeString(json, Strings.toString(dataId), out);
    }

    /// @dev serializes rebalance transaction data and adds it to the global json
    /// @param dataBefore strategy data before transaction
    /// @param dataAfter strategy data after transaction
    function _addRebalanceDataPoint(
        StrategyData memory dataBefore,
        StrategyData memory dataAfter
    ) internal {
        string memory obj = "rebalanceObj";
        vm.serializeUint(obj, "timestamp", block.timestamp);
        vm.serializeUint(
            obj, "ColAssetPrice", _getPrice(strategy.getAssets().underlying)
        );
        vm.serializeUint(
            obj, "DebtAssetPrice", _getPrice(strategy.getAssets().debt)
        );
        vm.serializeString(obj, "action", "REBALANCE");
        vm.serializeString(
            obj, "dataBefore", _serializeStrategyData(dataBefore)
        );
        vm.serializeString(obj, "dataAfter", _serializeStrategyData(dataAfter));

        dataId++;
        string memory out = vm.serializeUint(obj, "dataId", dataId);
        jsonOut = vm.serializeString(json, Strings.toString(dataId), out);
    }

    /// @dev returns the price of the given token
    /// @param token token to return price for
    /// @return price price of the token
    function _getPrice(IERC20 token) internal view returns (uint256 price) {
        return IPriceOracleGetter(strategy.getOracle()).getAssetPrice(
            address(token)
        );
    }
}
