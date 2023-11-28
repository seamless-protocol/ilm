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
        __ERC4626_init(_strategyAssets.underlying);
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
    function equityUSD() public view override returns (uint256 amount) {
        LoanState memory state =
            LoanLogic.getLoanState(Storage.layout().lendingPool);
        return state.collateralUSD - state.debtUSD;
    }

    /// @inheritdoc ILoopStrategy
    function equity() public view override returns (uint256 amount) {
        Storage.Layout storage $ = Storage.layout();
        // get underlying price and decimals
        uint256 underlyingPriceUSD =
            $.oracle.getAssetPrice(address($.assets.underlying));
        uint256 underlyingDecimals =
            IERC20Metadata(address($.assets.underlying)).decimals();

        return RebalanceLogic.convertUSDToAsset(
            equityUSD(), underlyingPriceUSD, underlyingDecimals
        );
    }

    /// @inheritdoc ILoopStrategy
    function debt() external view override returns (uint256 amount) {
        return LoanLogic.getLoanState(Storage.layout().lendingPool).debtUSD;
    }

    /// @inheritdoc ILoopStrategy
    function collateral() external view override returns (uint256 amount) {
        return
            LoanLogic.getLoanState(Storage.layout().lendingPool).collateralUSD;
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
        return RebalanceLogic.collateralRatioUSD(
            state.collateralUSD, state.debtUSD
        );
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
        return RebalanceLogic.rebalanceTo(
            $,
            LoanLogic.getLoanState($.lendingPool),
            0,
            $.collateralRatioTargets.target
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
        return _shouldRebalance(
            RebalanceLogic.collateralRatioUSD(
                state.collateralUSD, state.debtUSD
            ),
            $.collateralRatioTargets
        );
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
        uint256 currentCR = RebalanceLogic.collateralRatioUSD(
            state.collateralUSD, state.debtUSD
        );
        uint256 estimateTargetCR;

        uint256 underlyingPrice =
            $.oracle.getAssetPrice(address($.assets.underlying));
        uint256 assetsUSD = RebalanceLogic.convertAssetToUSD(
            assets,
            underlyingPrice,
            IERC20Metadata(address($.assets.underlying)).decimals()
        );

        if (currentCR == type(uint256).max) {
            estimateTargetCR = $.collateralRatioTargets.target;
        } else {
            if (_shouldRebalance(currentCR, $.collateralRatioTargets)) {
                currentCR = $.collateralRatioTargets.target;
            }

            uint256 afterCR = RebalanceLogic.collateralRatioUSD(
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
        uint256 estimatedEquityUSD = collateralAfterUSD - borrowAmount;

        uint256 underlyingPriceUSD =
            $.oracle.getAssetPrice(address($.assets.underlying));
        uint256 underlyingDecimals =
            IERC20Metadata(address($.assets.underlying)).decimals();

        uint256 estimatedEquity = RebalanceLogic.convertUSDToAsset(
            estimatedEquityUSD, underlyingPriceUSD, underlyingDecimals
        );
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
    {
        return _redeemV3(shares, receiver, owner, 0);
    }

    /// @inheritdoc ILoopStrategy
    function redeem(
        uint256 shares,
        address receiver,
        address owner,
        uint256 minUnderlyingAsset
    ) public whenNotPaused returns (uint256 assets) {
        return _redeemV2(shares, receiver, owner, minUnderlyingAsset);
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 shares)
        public
        view
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256)
    {
        Storage.Layout storage $ = Storage.layout();

        // get underlying price and decimals
        uint256 underlyingPriceUSD =
            $.oracle.getAssetPrice(address($.assets.underlying));
        uint256 underlyingDecimals =
            IERC20Metadata(address($.assets.underlying)).decimals();

        // get current loan state and calculate initial collateral ratio
        LoanState memory state = LoanLogic.getLoanState($.lendingPool);

        // check if collateralRatio is outside range, so user participates in potential rebalance
        if (
            _shouldRebalance(
                _collateralRatioUSD(state.collateralUSD, state.debtUSD),
                $.collateralRatioTargets
            )
        ) {
            // calculate amount of collateral needed to bring the collateral ratio
            // to target
            uint256 neededCollateralUSD = RebalanceLogic.requiredCollateralUSD(
                $.collateralRatioTargets.target,
                state.collateralUSD,
                state.debtUSD,
                $.swapper.offsetFactor($.assets.underlying, $.assets.debt)
            );

            // calculate new debt and collateral values after collateral has been exchanged
            // for rebalance
            state.collateralUSD -= neededCollateralUSD;
            state.debtUSD -= RebalanceLogic.offsetUSDAmountDown(
                neededCollateralUSD,
                $.swapper.offsetFactor($.assets.underlying, $.assets.debt)
            );
        }

        // calculate amount of debt and equity corresponding to shares in USD value
        (uint256 shareDebtUSD, uint256 shareEquityUSD) =
            _shareDebtAndEquity(state, shares, totalSupply());

        if (
            _collateralRatioUSD(
                state.collateralUSD - shareEquityUSD, state.debtUSD
            ) < $.collateralRatioTargets.minForWithdrawRebalance
        ) {
            uint256 collateralNeededUSD = shareDebtUSD.usdDiv(
                USDWadRayMath.USD
                    - $.swapper.offsetFactor($.assets.underlying, $.assets.debt)
            );

            shareEquityUSD -= collateralNeededUSD.usdMul(
                $.swapper.offsetFactor($.assets.underlying, $.assets.debt)
            );
        }

        uint256 shareEquityAsset = RebalanceLogic.convertUSDToAsset(
            shareEquityUSD, underlyingPriceUSD, underlyingDecimals
        );

        return shareEquityAsset;
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

        uint256 collateralRatio = RebalanceLogic.collateralRatioUSD(
            state.collateralUSD, state.debtUSD
        );

        if (
            collateralRatio != type(uint256).max
                && _shouldRebalance(collateralRatio, $.collateralRatioTargets)
        ) {
            collateralRatio = RebalanceLogic.rebalanceTo(
                $, state, 0, $.collateralRatioTargets.target
            );
        }

        uint256 prevTotalAssets = totalAssets();
        uint256 prevCollateralRatio = collateralRatio;

        state = LoanLogic.supply($.lendingPool, $.assets.collateral, assets);
        uint256 afterCollateralRatio = RebalanceLogic.collateralRatioUSD(
            state.collateralUSD, state.debtUSD
        );

        if (prevCollateralRatio == type(uint256).max) {
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

    /// @notice redeems an amount of shares by burning shares from the owner, and rewarding the receiver with
    /// the share value
    /// @param shares amount of shares to burn
    /// @param receiver address to receive share value
    /// @param owner address of share owner
    /// @param minUnderlyingAsset minimum amount of underlying asset to receive
    /// @return assets amount of underlying asset received
    function _redeemV2(
        uint256 shares,
        address receiver,
        address owner,
        uint256 minUnderlyingAsset
    ) internal returns (uint256 assets) {
        Storage.Layout storage $ = Storage.layout();

        // ensure that only owner can redeem owner's shares
        if (msg.sender != owner) {
            revert RedeemerNotOwner();
        }

        // get current loan state
        LoanState memory state = LoanLogic.getLoanState($.lendingPool);

        // check if collateralRatio is outside range, so user participates in potential rebalance
        if (
            _shouldRebalance(
                _collateralRatioUSD(state.collateralUSD, state.debtUSD),
                $.collateralRatioTargets
            )
        ) {
            RebalanceLogic.rebalanceTo(
                $, state, 0, $.collateralRatioTargets.target
            );

            state = LoanLogic.getLoanState($.lendingPool);
        }

        uint256 initialEquityUSD = equityUSD();

        // calculate amount of debt and equity corresponding to shares in USD value
        (uint256 shareDebtUSD, uint256 shareEquityUSD) =
            _shareDebtAndEquity(state, shares, totalSupply());

        // burn shares from the owner
        _burn(owner, shares);

        // check if withdrawing the shareEquity in USD value would lead to a collateral ratio
        // below the minimum limit for a rebalance after a withdrawal
        if (
            _collateralRatioUSD(
                state.collateralUSD - shareEquityUSD, state.debtUSD
            ) < $.collateralRatioTargets.minForWithdrawRebalance
        ) {
            // rebalance to initial CR
            RebalanceLogic.rebalanceTo(
                $,
                state,
                0,
                RebalanceLogic.collateralRatioUSD(
                    state.collateralUSD
                        - shareDebtUSD.usdDiv(
                            USDWadRayMath.USD
                                - $.swapper.offsetFactor(
                                    $.assets.collateral, $.assets.debt
                                )
                        ),
                    state.debtUSD - shareDebtUSD
                )
            );

            // since a rebalance occured, value is extracted by the DEX from swapping,
            // meaning that an amount of equity was lost:
            // lostEquity = initialEquity - finalEquity
            // so adjust shareEquityUSD accordingly since withdrawal is cause for rebalance
            shareEquityUSD -= initialEquityUSD - equityUSD();
        }

        // convert equity to collateral asset
        uint256 shareEquityAsset = RebalanceLogic.convertUSDToAsset(
            shareEquityUSD,
            $.oracle.getAssetPrice(address($.assets.collateral)),
            IERC20Metadata(address($.assets.collateral)).decimals()
        );

        // withdraw and transfer equity asset amount
        LoanLogic.withdraw($.lendingPool, $.assets.collateral, shareEquityAsset);

        uint256 shareUnderlyingAsset =
            _convertCollateralToUnderlyingAsset($.assets, shareEquityAsset);

        // ensure equity in asset terms to be received is larger than
        // minimum acceptable amount
        if (shareUnderlyingAsset < minUnderlyingAsset) {
            revert UnderlyingReceivedBelowMinimum(
                shareUnderlyingAsset, minUnderlyingAsset
            );
        }

        $.assets.underlying.transfer(receiver, shareUnderlyingAsset);

        return shareUnderlyingAsset;
    }

    /// @notice redeems an amount of shares by burning shares from the owner, and rewarding the receiver with
    /// the share value
    /// @param shares amount of shares to burn
    /// @param receiver address to receive share value
    /// @param owner address of share owner
    /// @param minUnderlyingAsset minimum amount of underlying asset to receive
    /// @return assets amount of underlying asset received
    function _redeemV3(
        uint256 shares,
        address receiver,
        address owner,
        uint256 minUnderlyingAsset
    ) internal returns (uint256 assets) {
        Storage.Layout storage $ = Storage.layout();

        // ensure that only owner can redeem owner's shares
        if (msg.sender != owner) {
            revert RedeemerNotOwner();
        }

        // get current loan state and calculate initial collateral ratio
        LoanState memory state = LoanLogic.getLoanState($.lendingPool);

        // check if collateralRatio is outside range, so user participates in potential rebalance
        if (
            _shouldRebalance(
                _collateralRatioUSD(state.collateralUSD, state.debtUSD),
                $.collateralRatioTargets
            )
        ) {
            RebalanceLogic.rebalanceTo(
                $, state, 0, $.collateralRatioTargets.target
            );

            state = LoanLogic.getLoanState($.lendingPool);
        }

        // initial equity prior to any actions specific for handling withdrawal
        uint256 initialEquityUSD = equityUSD();

        // calculate amount of debt and equity corresponding to shares in USD value
        (uint256 shareDebtUSD, uint256 shareEquityUSD) =
            _shareDebtAndEquity(state, shares, totalSupply());

        // burn shares from the owner after all calculations are done
        _burn(owner, shares);

        // check if withdrawal would lead to a collateral below minimum acceptable level
        // if yes, rebalance until share debt is repaid, and decrease remaining share equity
        // by equity cost of rebalance
        if (
            _collateralRatioUSD(
                state.collateralUSD - shareEquityUSD, state.debtUSD
            ) < $.collateralRatioTargets.minForWithdrawRebalance
        ) {
            // pay back the debt corresponding to the shares
            RebalanceLogic.rebalanceDownToDebt(
                $, state, state.debtUSD - shareDebtUSD
            );

            // calculate remaining equity after rebalance cost
            shareEquityUSD -= initialEquityUSD - equityUSD();
        }

        // convert equity to collateral asset
        uint256 shareEquityAsset = RebalanceLogic.convertUSDToAsset(
            shareEquityUSD,
            $.oracle.getAssetPrice(address($.assets.collateral)),
            IERC20Metadata(address($.assets.collateral)).decimals()
        );

        // withdraw and transfer equity asset amount
        LoanLogic.withdraw($.lendingPool, $.assets.collateral, shareEquityAsset);

        uint256 shareUnderlyingAsset =
            _convertCollateralToUnderlyingAsset($.assets, shareEquityAsset);

        // ensure equity in asset terms to be received is larger than
        // minimum acceptable amount
        if (shareUnderlyingAsset < minUnderlyingAsset) {
            revert UnderlyingReceivedBelowMinimum(
                shareUnderlyingAsset, minUnderlyingAsset
            );
        }

        $.assets.underlying.transfer(receiver, shareUnderlyingAsset);

        return shareUnderlyingAsset;
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

    function maxBorrowUSD() external view returns (uint256) {
        Storage.Layout storage $ = Storage.layout();
        return LoanLogic.getMaxBorrowUSD(
            $.lendingPool,
            $.assets.debt,
            $.oracle.getAssetPrice(address($.assets.debt))
        );
    }

    /// @notice unwrap collateral asset to the underlying asset, if those are different
    /// @param assets struct which contain underlying asset address and collateral asset address
    /// @param collateralAmountAsset amount of collateral asset to unwrap
    /// @return underlyingAmountAsset amount of received underlying assets
    function _convertCollateralToUnderlyingAsset(
        StrategyAssets storage assets,
        uint256 collateralAmountAsset
    ) internal virtual returns (uint256 underlyingAmountAsset) {
        if (assets.underlying != assets.collateral) {
            IWrappedERC20PermissionedDeposit(address(assets.underlying))
                .withdraw(collateralAmountAsset);
        }
        underlyingAmountAsset = collateralAmountAsset;
    }

    /// @notice calculates the debt, and equity corresponding to an amount of shares
    /// @dev collateral corresponding to shares is just sum of debt and equity
    /// @param state loan state of strategy
    /// @param shares amount of shares
    /// @param totalShares total supply of shares
    /// @return shareDebtUSD amount of debt in USD corresponding to shares
    /// @return shareEquityUSD amount of equity in USD corresponding to shares
    function _shareDebtAndEquity(
        LoanState memory state,
        uint256 shares,
        uint256 totalShares
    ) internal pure returns (uint256 shareDebtUSD, uint256 shareEquityUSD) {
        // calculate amount of debt and equity corresponding to shares in USD value
        shareDebtUSD = state.debtUSD.usdMul(
            USDWadRayMath.wadToUSD(shares.wadDiv(totalShares))
        );
        // to calculate equity, first collateral is calculated, and debt is subtracted from it
        shareEquityUSD = state.collateralUSD.usdMul(
            USDWadRayMath.wadToUSD(shares.wadDiv(totalShares))
        ) - shareDebtUSD;
    }
}
