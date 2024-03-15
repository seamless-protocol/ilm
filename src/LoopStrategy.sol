// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { ERC4626Upgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
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
import { ConversionMath } from "./libraries/math/ConversionMath.sol";
import { RebalanceMath } from "./libraries/math/RebalanceMath.sol";
import { USDWadRayMath } from "./libraries/math/USDWadRayMath.sol";
import { SafeERC20 } from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ISwapper } from "./interfaces/ISwapper.sol";
import { IWrappedERC20PermissionedDeposit } from
    "./interfaces/IWrappedERC20PermissionedDeposit.sol";
import { AccessControlUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title LoopStrategy
/// @notice Integrated Liquidity Market strategy for amplifying the cbETH staking rewards
contract LoopStrategy is
    ILoopStrategy,
    ERC4626Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using USDWadRayMath for uint256;

    /// @dev role which can pause and unpause deposits and withdrawals
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    /// @dev role which can change strategy parameters
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    /// @dev role which can upgrade the contract
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    constructor() {
        _disableInitializers();
    }

    function LoopStrategy_init(
        string memory _erc20name,
        string memory _erc20symbol,
        address _initialAdmin,
        StrategyAssets memory _strategyAssets,
        CollateralRatio memory _collateralRatioTargets,
        IPoolAddressesProvider _poolAddressProvider,
        IPriceOracleGetter _oracle,
        ISwapper _swapper,
        uint256 _ratioMargin,
        uint16 _maxIterations
    ) external initializer {
        __ERC4626_init(_strategyAssets.underlying);
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ERC20_init(_erc20name, _erc20symbol);

        _grantRole(DEFAULT_ADMIN_ROLE, _initialAdmin);

        _validateCollateralRatioTargets(_collateralRatioTargets);
        _validateRatioMargin(_ratioMargin);

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
            interestRateMode: 2,
            sTokenCollateral: LoanLogic.getSToken(
                $.poolAddressProvider, $.assets.collateral
                )
        });

        // there is no assets cap until it's otherwise set by the setter function
        $.assetsCap = type(uint256).max;

        // approving to lending pool collateral and debt assets in advance
        $.assets.collateral.approve(
            address($.lendingPool.pool), type(uint256).max
        );
        $.assets.debt.approve(address($.lendingPool.pool), type(uint256).max);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    { }

    /// @inheritdoc ILoopStrategy
    function pause() external override onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @inheritdoc ILoopStrategy
    function unpause() external override onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @inheritdoc ILoopStrategy
    function setInterestRateMode(uint256 _interestRateMode)
        external
        override
        onlyRole(MANAGER_ROLE)
    {
        Storage.layout().lendingPool.interestRateMode = _interestRateMode;
    }

    /// @dev validates collateral ratio targets values
    /// @param targets collateral ratio targets to validate
    function _validateCollateralRatioTargets(CollateralRatio memory targets)
        internal
        pure
    {
        if (
            targets.minForWithdrawRebalance > targets.target
                || targets.maxForDepositRebalance < targets.target
                || targets.minForRebalance > targets.minForWithdrawRebalance
                || targets.maxForRebalance < targets.maxForDepositRebalance
                || targets.minForRebalance == 0
                || targets.maxForRebalance == type(uint256).max
        ) {
            revert InvalidCollateralRatioTargets();
        }
    }

    /// @inheritdoc ILoopStrategy
    function setCollateralRatioTargets(CollateralRatio memory targets)
        external
        override
        onlyRole(MANAGER_ROLE)
    {
        _validateCollateralRatioTargets(targets);

        Storage.layout().collateralRatioTargets = targets;

        emit CollateralRatioTargetsSet(targets);

        if (rebalanceNeeded()) {
            rebalance();
        }
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
        return _convertUSDValueToUnderlyingAsset(equityUSD());
    }

    /// @inheritdoc ILoopStrategy
    function debtUSD() external view override returns (uint256 amount) {
        return LoanLogic.getLoanState(Storage.layout().lendingPool).debtUSD;
    }

    /// @inheritdoc ILoopStrategy
    function collateralUSD() external view override returns (uint256 amount) {
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
        return
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);
    }

    /// @inheritdoc ILoopStrategy
    function rebalance()
        public
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
        uint256 currentCR =
            RebalanceMath.collateralRatioUSD(state.collateralUSD, state.debtUSD);

        return state.collateralUSD != 0
            && RebalanceLogic.isCollateralRatioOutOfBounds(
                currentCR, $.collateralRatioTargets
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
    function maxDeposit(address)
        public
        view
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256)
    {
        return Storage.layout().assetsCap - totalAssets();
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
        return _convertToShares(
            RebalanceLogic.estimateSupply(Storage.layout(), assets),
            totalAssets()
        );
    }

    /// @notice mint function is disabled because we can't get exact amount of input assets for given amount of resulting shares
    function maxMint(address)
        public
        pure
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256)
    {
        return 0;
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
    function previewMint(uint256)
        public
        view
        override(ERC4626Upgradeable, IERC4626)
        whenNotPaused
        returns (uint256)
    {
        revert MintDisabled();
    }

    /// @notice withdraw function is disabled because the exact amount of shares for a number of
    /// tokens cannot be calculated accurately
    function maxWithdraw(address)
        public
        pure
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256)
    {
        return 0;
    }

    /// @notice withdraw function is disabled because the exact amount of shares for a number of
    /// tokens cannot be calculated accurately
    function withdraw(uint256, address, address)
        public
        view
        override(ERC4626Upgradeable, IERC4626)
        whenNotPaused
        returns (uint256)
    {
        revert WithdrawDisabled();
    }

    /// @notice withdraw function is disabled because the exact amount of shares for a number of
    /// tokens cannot be calculated accurately
    function previewWithdraw(uint256)
        public
        view
        override(ERC4626Upgradeable, IERC4626)
        whenNotPaused
        returns (uint256)
    {
        revert WithdrawDisabled();
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 shares, address receiver, address owner)
        public
        override(ERC4626Upgradeable, IERC4626)
        whenNotPaused
        returns (uint256)
    {
        return _redeem(shares, receiver, owner, 0);
    }

    /// @inheritdoc ILoopStrategy
    function redeem(
        uint256 shares,
        address receiver,
        address owner,
        uint256 minUnderlyingAsset
    ) external whenNotPaused returns (uint256 assets) {
        return _redeem(shares, receiver, owner, minUnderlyingAsset);
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 shares)
        public
        view
        override(ERC4626Upgradeable, IERC4626)
        returns (uint256)
    {
        return RebalanceLogic.estimateWithdraw(
            Storage.layout(), shares, totalSupply()
        );
    }

    /// @inheritdoc ILoopStrategy
    function setAssetsCap(uint256 assetsCap) external onlyRole(MANAGER_ROLE) {
        Storage.layout().assetsCap = assetsCap;

        emit AssetsCapSet(assetsCap);
    }

    /// @dev validates the marginUSD vlue
    /// @param marginUSD value to validate
    function _validateRatioMargin(uint256 marginUSD) internal pure {
        if (marginUSD > USDWadRayMath.USD) {
            revert MarginOutsideRange();
        }
    }

    /// @inheritdoc ILoopStrategy
    function setRatioMargin(uint256 marginUSD)
        external
        onlyRole(MANAGER_ROLE)
    {
        _validateRatioMargin(marginUSD);

        Storage.layout().ratioMargin = marginUSD;

        emit RatioMarginSet(marginUSD);
    }

    /// @inheritdoc ILoopStrategy
    function setMaxIterations(uint16 iterations)
        external
        onlyRole(MANAGER_ROLE)
    {
        Storage.layout().maxIterations = iterations;

        emit MaxIterationsSet(iterations);
    }

    /// @inheritdoc ILoopStrategy
    function setSwapper(address swapper) external onlyRole(MANAGER_ROLE) {
        Storage.layout().swapper = ISwapper(swapper);

        emit SwapperSet(swapper);
    }

    /// @inheritdoc ILoopStrategy
    function getAssets() external view returns (StrategyAssets memory assets) {
        return Storage.layout().assets;
    }

    /// @inheritdoc ILoopStrategy
    function getPoolAddressProvider()
        external
        view
        returns (address poolAddressProvider)
    {
        return address(Storage.layout().poolAddressProvider);
    }

    /// @inheritdoc ILoopStrategy
    function getLendingPool() external view returns (LendingPool memory pool) {
        return Storage.layout().lendingPool;
    }

    /// @inheritdoc ILoopStrategy
    function getOracle() external view returns (address oracle) {
        return address(Storage.layout().oracle);
    }

    /// @inheritdoc ILoopStrategy
    function getSwapper() external view returns (address swapper) {
        return address(Storage.layout().swapper);
    }

    /// @inheritdoc ILoopStrategy
    function getRatioMargin() external view returns (uint256 marginUSD) {
        return Storage.layout().ratioMargin;
    }

    /// @inheritdoc ILoopStrategy
    function getMaxIterations() external view returns (uint256 iterations) {
        return Storage.layout().maxIterations;
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

        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }

        SafeERC20.safeTransferFrom(
            $.assets.underlying, msg.sender, address(this), assets
        );

        assets = _convertUnderlyingToCollateralAsset($.assets, assets);

        LoanState memory state = RebalanceLogic.updateState($);

        uint256 prevTotalAssets = totalAssets();

        RebalanceLogic.rebalanceAfterSupply($, state, assets);

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
    function _redeem(
        uint256 shares,
        address receiver,
        address owner,
        uint256 minUnderlyingAsset
    ) internal returns (uint256 assets) {
        Storage.Layout storage $ = Storage.layout();

        uint256 shareUnderlyingAsset = _convertCollateralToUnderlyingAsset(
            $.assets,
            RebalanceLogic.rebalanceBeforeWithdraw($, shares, totalSupply())
        );

        // ensure equity in asset terms to be received is larger than
        // minimum acceptable amount
        if (shareUnderlyingAsset < minUnderlyingAsset) {
            revert UnderlyingReceivedBelowMinimum(
                shareUnderlyingAsset, minUnderlyingAsset
            );
        }

        // burn shares from owner and send corresponding underlying asset ammount to receiver
        _withdraw(_msgSender(), receiver, owner, shareUnderlyingAsset, shares);

        return shareUnderlyingAsset;
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
    /// @param assets struct which contain underlying asset address and collateral asset address
    /// @param collateralAmountAsset amount of collateral to convert
    /// @return receivedAssets amount of received collateral assets
    function _convertUnderlyingToCollateralAsset(
        StrategyAssets storage assets,
        uint256 collateralAmountAsset
    ) internal virtual returns (uint256 receivedAssets) {
        if (assets.underlying != assets.collateral) {
            assets.underlying.approve(
                address(assets.collateral), collateralAmountAsset
            );
            IWrappedERC20PermissionedDeposit(address(assets.collateral)).deposit(
                collateralAmountAsset
            );
        }
        receivedAssets = collateralAmountAsset;
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
            IWrappedERC20PermissionedDeposit(address(assets.collateral))
                .withdraw(collateralAmountAsset);
        }
        underlyingAmountAsset = collateralAmountAsset;
    }

    /// @notice converts the USD value to the amount of underlying token assets
    /// @param usdValue amount of USD to convert
    function _convertUSDValueToUnderlyingAsset(uint256 usdValue)
        internal
        view
        returns (uint256)
    {
        Storage.Layout storage $ = Storage.layout();

        // get underlying price and decimals
        uint256 underlyingPriceUSD =
            $.oracle.getAssetPrice(address($.assets.underlying));
        uint256 underlyingDecimals =
            IERC20Metadata(address($.assets.underlying)).decimals();

        return ConversionMath.convertUSDToAsset(
            usdValue,
            underlyingPriceUSD,
            underlyingDecimals,
            Math.Rounding.Floor
        );
    }
}
