// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";
import { IPool } from "@aave/contracts/interfaces/IPool.sol";
import { IPoolAddressesProvider } from
    "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPoolDataProvider } from
    "@aave/contracts/interfaces/IPoolDataProvider.sol";
import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { IAaveOracle } from "@aave/contracts/interfaces/IAaveOracle.sol";
import { IACLManager } from "@aave/contracts/interfaces/IACLManager.sol";
import { Errors } from "@aave/contracts/protocol/libraries/helpers/Errors.sol";
import { PercentageMath } from
    "@aave/contracts/protocol/libraries/math/PercentageMath.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ISwapper } from "../../src/interfaces/ISwapper.sol";
import { SwapperMock } from "../mock/SwapperMock.t.sol";
import {
    LendingPool,
    LoanState,
    StrategyAssets,
    CollateralRatio
} from "../../src/types/DataTypes.sol";
import { LoopStrategy, ILoopStrategy } from "../../src/LoopStrategy.sol";
import { WrappedCbETH } from "../../src/tokens/WrappedCbETH.sol";
import { USDWadRayMath } from "../../src/libraries/math/USDWadRayMath.sol";
import { MockAaveOracle } from "../mock/MockAaveOracle.sol";
import { LoanLogic } from "../../src/libraries/LoanLogic.sol";
import { RebalanceLogic } from "../../src/libraries/RebalanceLogic.sol";
import { stdStorage, StdStorage } from "forge-std/StdStorage.sol";
import { LoopStrategyTest } from "../unit/LoopStrategy.t.sol";
import { DeployTenderlyFork } from "../../deploy/DeployTenderlyFork.s.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { stdStorage, StdStorage } from "forge-std/StdStorage.sol";
import { IntegrationBase } from "./IntegrationBase.sol";
import "forge-std/console.sol";

contract SimulationHandler is Test {
    using stdStorage for StdStorage;

    LoopStrategy public strategy;
    uint256 public numUsers;

    uint256 public constant minDeposit = 0.1 ether;
    uint256 public constant maxDeposit = 5 ether;

    string public constant json = "json";
    string public jsonPath;
    string public jsonOut;
    uint256 public dataId;

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

    constructor(
        LoopStrategy _strategy,
        uint256 _numUsers,
        uint256 _startUnderlyingAmount,
        string memory _jsonPath
    ) {
        strategy = _strategy;
        numUsers = _numUsers;
        jsonPath = _jsonPath;

        address underlying = address(strategy.getAssets().underlying);
        for (uint256 i = 1; i <= numUsers; i++) {
            deal(underlying, vm.addr(i), _startUnderlyingAmount);
        }
    }

    function deposit(uint256 seed) public {
        uint256 userId = bound(seed, 1, numUsers);
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
            user, userId, amount, previewDeposit, dataBefore, dataAfter
        );
    }

    function redeem(uint256 seed) public {
        uint256 userId = bound(seed, 1, numUsers);
        address user = vm.addr(bound(seed, 1, numUsers));

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
                user, userId, userShares, previewRedeem, dataBefore, dataAfter
            );
        }
    }

    function _getStrategyData(address user)
        internal
        view
        returns (StrategyData memory)
    {
        return StrategyData({
            collateral: strategy.collateral(),
            debt: strategy.debt(),
            collateralRatio: strategy.currentCollateralRatio(),
            equity: strategy.equity(),
            equityUSD: strategy.equityUSD(),
            totalSupply: strategy.totalSupply(),
            rebalanceNeeded: strategy.rebalanceNeeded(),
            userShares: strategy.balanceOf(user),
            userBalance: strategy.getAssets().underlying.balanceOf(user)
        });
    }

    function _checkEquity(
        StrategyData memory dataBefore,
        StrategyData memory dataAfter
    ) internal {
        if (!dataBefore.rebalanceNeeded) {
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

    function saveJson() public {
        vm.writeJson(jsonOut, jsonPath);
    }

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

    function _addDepositDataPoint(
        address user,
        uint256 userId,
        uint256 amount,
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
        vm.serializeUint(obj, "preview", previewDeposit);
        vm.serializeString(
            obj, "dataBefore", _serializeStrategyData(dataBefore)
        );
        vm.serializeString(obj, "dataAfter", _serializeStrategyData(dataAfter));

        dataId++;
        string memory out = vm.serializeUint(obj, "dataId", dataId);
        jsonOut = vm.serializeString(json, Strings.toString(dataId), out);
    }

    function _addRedeemDataPoint(
        address user,
        uint256 userId,
        uint256 amount,
        uint256 previewRedeem,
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
        vm.serializeString(obj, "action", "REDEEM");
        vm.serializeUint(obj, "amount", amount);
        vm.serializeUint(obj, "preview", previewRedeem);
        vm.serializeString(
            obj, "dataBefore", _serializeStrategyData(dataBefore)
        );
        vm.serializeString(obj, "dataAfter", _serializeStrategyData(dataAfter));

        dataId++;
        string memory out = vm.serializeUint(obj, "dataId", dataId);
        jsonOut = vm.serializeString(json, Strings.toString(dataId), out);
    }

    function _getPrice(IERC20 token) internal view returns (uint256) {
        return IPriceOracleGetter(strategy.getOracle()).getAssetPrice(
            address(token)
        );
    }
}
