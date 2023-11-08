// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { ERC4626Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {
    Ownable2StepUpgradeable,
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { IPriceOracleGetter } from
    "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { PausableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IPoolAddressesProvider } from
    "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPool } from "@aave/contracts/interfaces/IPool.sol";
import { ILoopStrategy, IERC4626 } from "./interfaces/ILoopStrategy.sol";
import { LoanLogic } from "./libraries/LoanLogic.sol";
import { RebalanceLogic } from "./libraries/RebalanceLogic.sol";
import { LoopStrategyStorage as Storage } from
    "./storage/LoopStrategyStorage.sol";
import {
    CollateralRatio,
    LoanState,
    LendingPool,
    StrategyAssets
} from "./types/DataTypes.sol";
import { USDWadRayMath } from "./libraries/math/USDWadRayMath.sol";
import { SafeERC20 } from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ISwapper } from "./interfaces/ISwapper.sol";
import { IWrappedERC20PermissionedDeposit } from
    "./interfaces/IWrappedERC20PermissionedDeposit.sol";

/// @title LoopStrategy
/// @notice Integrated Liquidity Market strategy for amplifying the cbETH staking rewards
contract LoopStrategy is
    ILoopStrategy,
    ERC4626Upgradeable,
    Ownable2StepUpgradeable,
    PausableUpgradeable
{
    function LoopStrategy_init(
        address _initialOwner,
        StrategyAssets memory _strategyAssets,
        CollateralRatio memory _collateralRatioTargets,
        IPoolAddressesProvider _poolAddressProvider,
        IPriceOracleGetter _oracle,
        ISwapper _swapper
    ) external initializer {
        __Ownable_init(_initialOwner);
        __ERC4626_init(_strategyAssets.collateral);
        __Pausable_init();

        Storage.Layout storage $ = Storage.layout();
        $.assets = _strategyAssets;
        $.collateralRatioTargets = _collateralRatioTargets;
        $.poolAddressProvider = _poolAddressProvider;
        $.oracle = _oracle;
        $.swapper = _swapper;

        $.lendingPool = LendingPool({
            pool: IPool(_poolAddressProvider.getPool()),
            // 2 is the variable interest rate mode
            interestRateMode: 2
        });

        // approving to lending pool collateral and debt assets in advance
        $.assets.collateral.approve(
            address($.lendingPool.pool), type(uint256).max
        );
        $.assets.debt.approve(address($.lendingPool.pool), type(uint256).max);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /// @inheritdoc ILoopStrategy
    function setInterestRateMode(uint256 _interestRateMode)
        external
        override
        onlyOwner
    {
        Storage.layout().lendingPool.interestRateMode = _interestRateMode;
    }

    /// @inheritdoc ILoopStrategy
    function setCollateralRatioTargets(
        CollateralRatio memory _collateralRatioTargets
    ) external override onlyOwner {
        Storage.layout().collateralRatioTargets = _collateralRatioTargets;
    }

    /// @inheritdoc ILoopStrategy
    function getCollateralRatioTargets()
        external
        view
        override
        returns (CollateralRatio memory ratio)
    {
        return Storage.layout().collateralRatioTargets;
    }

    /// @inheritdoc ILoopStrategy
    function equity() public view override returns (uint256 amount) {
        LoanState memory state = LoanLogic.getLoanState(Storage.layout().lendingPool);
        return state.collateralUSD - state.debtUSD;
    }

    /// @inheritdoc ILoopStrategy
    function debt() external view override returns (uint256 amount) {
        LoanState memory state = LoanLogic.getLoanState(Storage.layout().lendingPool);
        return state.debtUSD;
    }

    /// @inheritdoc ILoopStrategy
    function collateral() external view override returns (uint256 amount) {
        LoanState memory state = LoanLogic.getLoanState(Storage.layout().lendingPool);
        return state.collateralUSD;
    }

    /// @inheritdoc ILoopStrategy
    function currentCollateralRatio()
        external
        view
        override
        returns (uint256 ratio)
    {
        LoanState memory state = LoanLogic.getLoanState(Storage.layout().lendingPool);
        return _collateralRatioUSD(state.collateralUSD, state.debtUSD);
    }

    /// @inheritdoc ILoopStrategy
    function rebalance()
        external
        override
        whenNotPaused
        returns (uint256 ratio)
    {
        if (!rebalanceNeeded()) {
            revert RebalanceNotNeeded();
        }
        Storage.Layout storage $ = Storage.layout();
        LoanState memory state = LoanLogic.getLoanState($.lendingPool);
        return
            RebalanceLogic.rebalanceTo(state, $.collateralRatioTargets.target);
    }

    /// @inheritdoc ILoopStrategy
    function rebalanceNeeded()
        public
        view
        override
        returns (bool shouldRebalance)
    {
        Storage.Layout storage $ = Storage.layout();
        LoanState memory state = LoanLogic.getLoanState($.lendingPool);
        uint256 collateralRatio =
            _collateralRatioUSD(state.collateralUSD, state.debtUSD);
        return _shouldRebalance(collateralRatio, $.collateralRatioTargets);
    }

    /// @inheritdoc IERC4626
    function totalAssets()
        public
        view
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256)
    {
        return equity();
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 assets, address receiver)
        public
        override(ERC4626Upgradeable, IERC4626)
        whenNotPaused
        returns (uint256 shares)
    {
        (shares,) = _deposit(assets, receiver, 0);
    }

    /// @inheritdoc ILoopStrategy
    function deposit(
        uint256 assets,
        address receiver,
        uint256 minEquityReceived
    )
        external
        override
        whenNotPaused
        returns (uint256 shares, uint256 equityReceived)
    {
        (shares, equityReceived) = _deposit(assets, receiver, minEquityReceived);
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 assets)
        public
        view
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256)
    {
        (bool success, bytes memory result) = address(this).staticcall(
            abi.encodeWithSelector(
                IERC4626.deposit.selector, assets, address(0)
            )
        );

        if (!success) {
            revert DepositStaticcallReverted();
        }

        return abi.decode(result, (uint256));
    }

    /// @inheritdoc ILoopStrategy
    function previewDepositEquity(uint256 assets)
        external
        view
        returns (uint256 shares, uint256 equityExpected)
    {
        (bool success, bytes memory result) = address(this).staticcall(
            abi.encodeWithSelector(
                ILoopStrategy.deposit.selector, assets, address(0)
            )
        );

        if (!success) {
            revert DepositStaticcallReverted();
        }

        return abi.decode(result, (uint256, uint256));
    }

    /// @notice mint function is disabled because we can't get exact amount of input assets for given amount of resulting shares
    function mint(uint256, address)
        public
        view
        override(ERC4626Upgradeable, IERC4626)
        whenNotPaused
        returns (uint256)
    {
        revert MintDisabled();
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override(ERC4626Upgradeable, IERC4626)
        whenNotPaused
        returns (uint256)
    {
        // TODO: should we just revert and disable this function also?
        //       possible calculation of shares for given cbETH amount is described in PRD
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 shares, address receiver, address owner)
        public
        override(ERC4626Upgradeable, IERC4626)
        whenNotPaused
        returns (uint256)
    {
        // TODO: redeem flow
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 shares)
        public
        view
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256)
    {
        // TODO: static call redeem() and return the expected withdrawal amount
    }

    /// @dev returns if collateral ratio is out of the acceptable range and reabalance should happen
    /// @param collateralRatio given collateral ratio
    /// @param collateraRatioTargets struct which contain targets (min and max for rebalance)
    function _shouldRebalance(
        uint256 collateralRatio,
        CollateralRatio memory collateraRatioTargets
    ) internal pure returns (bool) {
        return (
            collateralRatio < collateraRatioTargets.minForRebalance
                || collateralRatio > collateraRatioTargets.maxForRebalance
        );
    }

    /// @notice deposit assets to the strategy with the requirement of equity received after rebalance
    /// @param assets amount of assets to deposit
    /// @param receiver address of the receiver of share tokens
    /// @param minEquityReceived required minimum of equity received
    /// @return shares number of received shares
    /// @return equityReceived amount of received equity
    function _deposit(
        uint256 assets,
        address receiver,
        uint256 minEquityReceived
    ) internal returns (uint256 shares, uint256 equityReceived) {
        Storage.Layout storage $ = Storage.layout();
        SafeERC20.safeTransferFrom(
            $.assets.underlying, msg.sender, address(this), assets
        );

        assets = _convertUnderlyingToCollateralAsset($.assets, assets);

        LoanState memory state = LoanLogic.getLoanState($.lendingPool);

        uint256 collateralRatio =
            _collateralRatioUSD(state.collateralUSD, state.debtUSD);

        if (
            collateralRatio != 0
                && _shouldRebalance(collateralRatio, $.collateralRatioTargets)
        ) {
            collateralRatio = RebalanceLogic.rebalanceTo(
                state, $.collateralRatioTargets.target
            );
        }

        uint256 prevTotalAssets = totalAssets();
        uint256 prevCollateralRatio = collateralRatio;

        state = LoanLogic.supply($.lendingPool, $.assets.collateral, assets);
        uint256 afterCollateralRatio =
            _collateralRatioUSD(state.collateralUSD, state.debtUSD);

        if (prevCollateralRatio == 0) {
            collateralRatio = RebalanceLogic.rebalanceTo(
                state, $.collateralRatioTargets.target
            );
        } else if (
            afterCollateralRatio
                > $.collateralRatioTargets.maxForDepositRebalance
        ) {
            uint256 rebalanceToRatio = prevCollateralRatio;
            if (
                $.collateralRatioTargets.maxForDepositRebalance
                    > rebalanceToRatio
            ) {
                rebalanceToRatio =
                    $.collateralRatioTargets.maxForDepositRebalance;
            }
            collateralRatio =
                RebalanceLogic.rebalanceTo(state, rebalanceToRatio);
        }

        equityReceived = totalAssets() - prevTotalAssets;
        if (equityReceived < minEquityReceived) {
            revert EquityReceivedBelowMinimum(equityReceived, minEquityReceived);
        }

        shares = _convertToShares(equityReceived, prevTotalAssets);
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
        return (shares, equityReceived);
    }

    /// @notice helper function to calculate collateral ratio
    /// @param collateralUSD collateral value in USD
    /// @param debtUSD debt valut in USD
    /// @return ratio collateral ratio value
    function _collateralRatioUSD(uint256 collateralUSD, uint256 debtUSD)
        internal
        pure
        returns (uint256 ratio)
    {
        ratio = debtUSD != 0 ? USDWadRayMath.usdDiv(collateralUSD, debtUSD) : 0;
    }

    /// @notice function is the same formula as in ERC4626 implementation, but totalAssets is passed as a parameter of the function
    /// @notice we are using this function because totalAssets may change before we are able to calculate asset(equity) amount;
    /// @notice that is because we are calculating assets based on change in totalAssets
    /// @param _assets amount of assets provided
    /// @param _totalAssets amount of total assets which are used in calculation of shares
    /// @return shares
    function _convertToShares(uint256 _assets, uint256 _totalAssets)
        internal
        view
        virtual
        returns (uint256 shares)
    {
        shares = Math.mulDiv(
            _assets,
            totalSupply() + 10 ** _decimalsOffset(),
            _totalAssets + 1,
            Math.Rounding.Floor
        );
    }

    /// @notice converts underlying asset to the collateral asset if those are different
    /// @param strategyAssets struct which contain underlying asset address and collateral asset address
    /// @param assets amount of assets to convert
    /// @return receivedAssets amount of received collateral assets
    function _convertUnderlyingToCollateralAsset(
        StrategyAssets storage strategyAssets,
        uint256 assets
    ) internal virtual returns (uint256 receivedAssets) {
        if (strategyAssets.underlying != strategyAssets.collateral) {
            strategyAssets.underlying.approve(
                address(strategyAssets.collateral), assets
            );
            IWrappedERC20PermissionedDeposit(address(strategyAssets.collateral))
                .deposit(assets);
        }
        receivedAssets = assets;
    }
}
