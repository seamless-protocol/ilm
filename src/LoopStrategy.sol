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
import { IERC20Metadata } from
    "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
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
    using USDWadRayMath for uint256;

    function LoopStrategy_init(
        address _initialOwner,
        StrategyAssets memory _strategyAssets,
        CollateralRatio memory _collateralRatioTargets,
        IPoolAddressesProvider _poolAddressProvider,
        IPriceOracleGetter _oracle,
        ISwapper _swapper,
        uint256 _ratioMargin,
        uint16 _maxIterations
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
        $.ratioMargin = _ratioMargin;
        $.maxIterations = _maxIterations;

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
        LoanState memory state =
            LoanLogic.getLoanState(Storage.layout().lendingPool);
        return state.collateralUSD - state.debtUSD;
    }

    /// @inheritdoc ILoopStrategy
    function debt() external view override returns (uint256 amount) {
        LoanState memory state =
            LoanLogic.getLoanState(Storage.layout().lendingPool);
        return state.debtUSD;
    }

    /// @inheritdoc ILoopStrategy
    function collateral() external view override returns (uint256 amount) {
        LoanState memory state =
            LoanLogic.getLoanState(Storage.layout().lendingPool);
        return state.collateralUSD;
    }

    /// @inheritdoc ILoopStrategy
    function currentCollateralRatio()
        external
        view
        override
        returns (uint256 ratio)
    {
        LoanState memory state =
            LoanLogic.getLoanState(Storage.layout().lendingPool);
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
        return RebalanceLogic.rebalanceTo(
            $, state, 0, $.collateralRatioTargets.target
        );
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
        shares = _deposit(assets, receiver, 0);
    }

    /// @inheritdoc ILoopStrategy
    function deposit(
        uint256 assets,
        address receiver,
        uint256 minSharesReceived
    ) external override whenNotPaused returns (uint256 shares) {
        shares = _deposit(assets, receiver, minSharesReceived);
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 assets)
        public
        view
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256)
    {
        Storage.Layout storage $ = Storage.layout();
        LoanState memory state = LoanLogic.getLoanState($.lendingPool);
        uint256 currentCR =
            _collateralRatioUSD(state.collateralUSD, state.debtUSD);
        uint256 estimateTargetCR;

        uint256 underlyingPrice =
            $.oracle.getAssetPrice(address($.assets.underlying));
        uint256 assetsUSD = RebalanceLogic.convertAssetToUSD(
            assets,
            underlyingPrice,
            IERC20Metadata(address($.assets.underlying)).decimals()
        );

        if (currentCR == 0) {
            estimateTargetCR = $.collateralRatioTargets.target;
        } else {
            if (_shouldRebalance(currentCR, $.collateralRatioTargets)) {
                currentCR = $.collateralRatioTargets.target;
            }

            uint256 afterCR = _collateralRatioUSD(
                state.collateralUSD + assetsUSD, state.debtUSD
            );
            if (afterCR > $.collateralRatioTargets.maxForDepositRebalance) {
                estimateTargetCR = currentCR;
                if (
                    $.collateralRatioTargets.maxForDepositRebalance
                        > estimateTargetCR
                ) {
                    estimateTargetCR =
                        $.collateralRatioTargets.maxForDepositRebalance;
                }
            } else {
                estimateTargetCR = afterCR;
            }
        }

        uint256 offsetFactor =
            $.swapper.offsetFactor($.assets.collateral, $.assets.debt);
        uint256 borrowAmount = RebalanceLogic.requiredBorrowUSD(
            estimateTargetCR, assetsUSD, 0, offsetFactor
        );
        uint256 collateralAfterUSD = borrowAmount.usdMul(estimateTargetCR);
        uint256 estimatedEquity = collateralAfterUSD - borrowAmount;
        return _convertToShares(estimatedEquity, totalAssets());
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

    /// @notice mint function is disabled because we can't get exact amount of input assets for given amount of resulting shares
    /// @dev returning 0 because previewMint function must not revert by the ERC4626 standard
    function previewMint(uint256)
        public
        view
        override(ERC4626Upgradeable, IERC4626)
        whenNotPaused
        returns (uint256)
    {
        return 0;
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
    { }

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
    /// @param minSharesReceived required minimum of equity received
    /// @return shares number of received shares
    function _deposit(
        uint256 assets,
        address receiver,
        uint256 minSharesReceived
    ) internal returns (uint256 shares) {
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
                $, state, 0, $.collateralRatioTargets.target
            );
        }

        uint256 prevTotalAssets = totalAssets();
        uint256 prevCollateralRatio = collateralRatio;

        state = LoanLogic.supply($.lendingPool, $.assets.collateral, assets);
        uint256 afterCollateralRatio =
            _collateralRatioUSD(state.collateralUSD, state.debtUSD);

        if (prevCollateralRatio == 0) {
            collateralRatio = RebalanceLogic.rebalanceTo(
                $, state, 0, $.collateralRatioTargets.target
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
                RebalanceLogic.rebalanceTo($, state, 0, rebalanceToRatio);
        }

        uint256 equityReceived = totalAssets() - prevTotalAssets;
        shares = _convertToShares(equityReceived, prevTotalAssets);

        if (shares < minSharesReceived) {
            revert SharesReceivedBelowMinimum(shares, minSharesReceived);
        }

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
        return shares;
    }

    function _redeem(
        uint256 shares,
        address receiver,
        address owner,
        uint256 minEquityReceivedUSD
    ) internal returns (uint256 assets, uint256 equityReceived) {
        Storage.Layout storage $ = Storage.layout();
        // burn shares from the owner
        _burn(owner, shares);

        // get collateral price and decimals
        uint256 collateralPriceUSD =
            $.oracle.getAssetPrice(address($.assets.collateral));
        uint256 collateralDecimals =
            IERC20Metadata(address($.assets.collateral)).decimals();

        // get current loan state and calculate initial collateral ratio
        LoanState memory state = LoanLogic.getLoanState($.lendingPool);
        uint256 initialCR =
            _collateralRatioUSD(state.collateralUSD, state.debtUSD);

        // check if collateralRatio is outside range, so user participates in potential rebalance
        if (_shouldRebalance(initialCR, $.collateralRatioTargets)) {
            initialCR = RebalanceLogic.rebalanceTo(
                $, state, 0, $.collateralRatioTargets.target
            );

            state = LoanLogic.getLoanState($.lendingPool);
        }
        // 300 cUSD
        // 200 dUSD
        // rebal as if 50 cUSD, so 50 cUSD leftover

        // calculate amount of collateral, debt and equity corresponding to shares in USD value
        uint256 shareCollateralUSD = state.collateralUSD.usdMul(
            USDWadRayMath.wadToUSD(shares.wadDiv(totalSupply()))
        );
        uint256 shareDebtUSD = state.debtUSD.usdMul(
            USDWadRayMath.wadToUSD(shares.wadDiv(totalSupply()))
        );
        uint256 shareEquityUSD = shareCollateralUSD - shareDebtUSD;

        uint256 initialDebtUSD = state.debtUSD;
        uint256 initialEquityUSD = equity();
        uint256 remainingDebtUSD = shareDebtUSD;
        uint256 debtRepaidUSD;

        // check beforehand CR effects

        // while there is outstanding debt on the user shares, rebalance downwards to repay debt
        while (0 < remainingDebtUSD) {
            // calculate collateral token withdraw amount by selecting the smaller of
            // the maximum withdrawable and remaining debt USD amounts and repay selected
            // debt amount
            state = _repayDebtWithCollateral(
                $,
                Math.min(
                    state.maxWithdrawAmount,
                    (remainingDebtUSD * USDWadRayMath.USD)
                        / (
                            USDWadRayMath.USD
                                - $.swapper.offsetFactor(
                                    $.assets.collateral, $.assets.debt
                                )
                        )
                ),
                collateralPriceUSD,
                collateralDecimals
            );

            debtRepaidUSD = initialDebtUSD - state.debtUSD;
            remainingDebtUSD =
                debtRepaidUSD < shareDebtUSD ? shareDebtUSD - debtRepaidUSD : 0;
        }

        // MIGHT CANCEL OUT WITH REBALANCE?
        // account for any excess debt
        uint256 excessRepaidUSD;
        if (debtRepaidUSD > shareDebtUSD) {
            excessRepaidUSD = debtRepaidUSD - shareDebtUSD;
        }

        // calculate bet share equity in USD value
        uint256 netShareEquityUSD = shareEquityUSD + excessRepaidUSD;

        // check if this variable is needed
        uint256 currentCR =
            _collateralRatioUSD(state.collateralUSD, state.debtUSD);

        // QUESTION:
        // 1. Can there be a situation where the rebalancing causes more fees than users left over equity?
        // 2. How to anticipate & handle?
        // if under the minimum for withdraw rebalance limit rebalance upwards
        if (currentCR > $.collateralRatioTargets.minForWithdrawRebalance) {
            uint256 preRebalanceDebtUSD = state.debtUSD;
            // NOTE: this is not accurate because the final amount of asset withdrawal
            // is actually less than the original accounted amount. How to fix?
            // calculate the collateral ratio to rebalance up to so that when
            // collateral is withdrawn, the initialCR is attained
            uint256 targetCR = (
                initialCR.usdMul(preRebalanceDebtUSD) + netShareEquityUSD
            ).usdDiv(preRebalanceDebtUSD);

            RebalanceLogic.rebalanceTo($, state, 0, targetCR);

            state = LoanLogic.getLoanState($.lendingPool);
        }

        // adjust netShareEquityUSD based on additional equity lost from swapping operations
        // Question:
        // 1. Is it possible for this to be overall negative? ie netShareEquityUSD < initialEquityUSD - equity()
        // 2. If yes, how to handle?
        // NOTE: this should be calculated with equity changes, not debt
        netShareEquityUSD -= (initialEquityUSD - equity());

        // make this check cbETH
        if (netShareEquityUSD < minEquityReceivedUSD) {
            revert EquityReceivedBelowMinimum(
                netShareEquityUSD, minEquityReceivedUSD
            );
        }

        // QUESTION:
        // Can there be a case where withdrawing the amount left over is too great to withdraw at once?
        // convert to collateral asset and transfer
        uint256 netShareCollateralAsset = RebalanceLogic.convertUSDToAsset(
            netShareEquityUSD, collateralPriceUSD, collateralDecimals
        );

        LoanLogic.withdraw(
            $.lendingPool, $.assets.collateral, netShareCollateralAsset
        );
        $.assets.collateral.transferFrom(
            address(this), receiver, netShareCollateralAsset
        );

        return (netShareCollateralAsset, netShareEquityUSD);
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

    function _convertToAssets(uint256 _shares)
        internal
        view
        virtual
        returns (uint256 assets)
    {
        assets = Math.mulDiv(equity(), _shares, totalSupply());
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

    function maxBorrowUSD() external view returns (uint256) {
        Storage.Layout storage $ = Storage.layout();
        return LoanLogic.getMaxBorrowUSD(
            $.lendingPool,
            $.assets.debt,
            $.oracle.getAssetPrice(address($.assets.debt))
        );
    }

    /// @notice converts collateral asset to the underlying asset if those are different
    /// @param assets struct which contain underlying asset address and collateral asset address
    /// @param assetAmount amount of assets to convert
    /// @return receivedAssets amount of received underlying assets
    function _convertCollateralToUnderlyingAsset(
        StrategyAssets storage assets,
        uint256 assetAmount
    ) internal virtual returns (uint256 receivedAssets) {
        if (assets.underlying != assets.collateral) {
            assets.collateral.approve(address(assets.underlying), assetAmount);
            IWrappedERC20PermissionedDeposit(address(assets.underlying))
                .withdraw(assetAmount);
        }
        receivedAssets = assetAmount;
    }

    function _repayDebtWithCollateral(
        Storage.Layout memory $,
        uint256 debtUSD,
        uint256 collateralPriceUSD,
        uint256 collateralDecimals
    ) internal returns (LoanState memory state) {
        // convert debt USD value to collateral asset amount
        uint256 withdrawAmountAsset = RebalanceLogic.convertUSDToAsset(
            debtUSD, collateralPriceUSD, collateralDecimals
        );

        state = LoanLogic.withdraw(
            $.lendingPool, $.assets.collateral, withdrawAmountAsset
        );

        $.assets.collateral.approve(address($.swapper), withdrawAmountAsset);

        // exchange withdrawAmountAsset of collateral tokens for debt tokens to repay
        uint256 repayAmountAsset = $.swapper.swap(
            $.assets.collateral,
            $.assets.debt,
            withdrawAmountAsset,
            payable(address(this))
        );

        // repay debt
        state = LoanLogic.repay($.lendingPool, $.assets.debt, repayAmountAsset);
    }
    // rebal case 1:
    // - overleverage, so you must pay for de-leverage
    // rebal case 2:
    // - underleverage, so "freebie"
    // run rebalanceTo with new state, and check equity loss
    // consider additional param to subtract from state
}
