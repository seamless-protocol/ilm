// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { ERC4626Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { Ownable2StepUpgradeable, OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { IPriceOracleGetter } from "@aave/contracts/interfaces/IPriceOracleGetter.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IPoolAddressesProvider } from "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPool } from "@aave/contracts/interfaces/IPool.sol"; 
import { ILoopStrategy, IERC4626 } from "./interfaces/ILoopStrategy.sol";
import { LoanLogic } from "./libraries/LoanLogic.sol";
import { RebalanceLogic } from "./libraries/RebalanceLogic.sol";
import { LoopStrategyStorage } from "./storage/LoopStrategyStorage.sol";
import { CollateralRatio, LoanState, LendingPool, StrategyAssets } from "./types/DataTypes.sol";
import { USDWadMath } from "./libraries/math/USDWadMath.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ISwapper } from "./interfaces/ISwapper.sol";

/// @title LoopCbETHStrategy
/// @notice Integrated Liquidity Market strategy for amplifying the cbETH staking rewards
contract LoopCbETHStrategy is
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
    ) internal initializer {
      __Ownable_init(_initialOwner);
      __ERC4626_init(_strategyAssets.collateral);
      __Pausable_init();

      LoopStrategyStorage.Layout storage $ = LoopStrategyStorage.layout();
      $.strategyAssets = _strategyAssets;
      $.collateralRatioTargets = _collateralRatioTargets;
      $.poolAddressProvider = _poolAddressProvider;
      $.oracle = _oracle;
      $.swapper = _swapper;

      $.lendingPool = LendingPool({
        pool: IPool(_poolAddressProvider.getPool()),
        // 2 is the variable interest rate mode
        interestRateMode: 2
      });
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /// @inheritdoc ILoopStrategy
    function setInterestRateMode(uint256 _interestRateMode) external override onlyOwner {
        LoopStrategyStorage.Layout storage $ = LoopStrategyStorage.layout();
        $.lendingPool.interestRateMode = _interestRateMode;
    }

    /// @inheritdoc ILoopStrategy
    function setCollateralRatioTargets(CollateralRatio memory _collateralTargets) external override onlyOwner {
        LoopStrategyStorage.Layout storage $ = LoopStrategyStorage.layout();
        $.collateralRatioTargets = _collateralTargets;
    }

    /// @inheritdoc ILoopStrategy
    function getCollateralRatioTargets() external view override returns (CollateralRatio memory ratio) {
        return LoopStrategyStorage.layout().collateralRatioTargets;
    }

    /// @inheritdoc ILoopStrategy
    function equity() public override view returns (uint256 amount) {
        LoopStrategyStorage.Layout storage $ = LoopStrategyStorage.layout();
        LoanState memory state = LoanLogic.getLoanState($.lendingPool);
        return state.collateralUSD - state.debtUSD;
    }

    /// @inheritdoc ILoopStrategy
    function debt() external override view returns (uint256 amount) {
        LoopStrategyStorage.Layout storage $ = LoopStrategyStorage.layout();
        LoanState memory state = LoanLogic.getLoanState($.lendingPool);
        return state.debtUSD;
    }

    /// @inheritdoc ILoopStrategy
    function collateral() external override view returns (uint256 amount) {
        LoopStrategyStorage.Layout storage $ = LoopStrategyStorage.layout();
        LoanState memory state = LoanLogic.getLoanState($.lendingPool);
        return state.collateralUSD;
    }

    /// @inheritdoc ILoopStrategy
    function currentCollateralRatio() external override returns (uint256 ratio) {
        // TODO: should this number from the LoanLogic lib, maybe even in LoanState
        LoopStrategyStorage.Layout storage $ = LoopStrategyStorage.layout();
        LoanState memory state = LoanLogic.getLoanState($.lendingPool);
        return _collateralRatioUSD(state.collateralUSD, state.debtUSD);
    }

    /// @inheritdoc ILoopStrategy
    function rebalance() external override whenNotPaused returns (uint256 ratio) {
        // TODO: if collateral ratio is out of the min/max range do the rebalancing
    }

    /// @inheritdoc IERC4626
    function totalAssets() public view override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        return equity();
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 assets, address receiver) public override(ERC4626Upgradeable, IERC4626) whenNotPaused returns (uint256) {
        LoopStrategyStorage.Layout storage $ = LoopStrategyStorage.layout();
        SafeERC20.safeTransferFrom($.strategyAssets.collateral, msg.sender, address(this), assets);
        
        LoanState memory state = LoanLogic.getLoanState($.lendingPool);

        uint256 collateralRatio = _collateralRatioUSD(state.collateralUSD, state.debtUSD);

        if (_shouldRebalance(collateralRatio, $.collateralRatioTargets)) {
            collateralRatio = _rebalanceTo(state, $.collateralRatioTargets.target);
        }

        uint256 prevTotalAssets = totalAssets();
        uint256 prevCollateralRatio = collateralRatio;

        state = LoanLogic.supply($.lendingPool, $.strategyAssets.collateral, assets);
        uint256 afterCollateralRatio = _collateralRatioUSD(state.collateralUSD, state.debtUSD);

        if (afterCollateralRatio > $.collateralRatioTargets.maxForDepositRebalance) {
            uint256 rebalanceToRatio = prevCollateralRatio;
            if ($.collateralRatioTargets.maxForDepositRebalance > rebalanceToRatio) {
                rebalanceToRatio = $.collateralRatioTargets.maxForDepositRebalance;
            }
            collateralRatio = _rebalanceTo(state, rebalanceToRatio);
        }

        uint256 afterTotalAssets = totalAssets();
        uint256 shares = convertToShares(afterTotalAssets - prevTotalAssets);
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
        return shares;
    }

    function _rebalanceTo(LoanState memory loanState, uint256 targetRatio) internal returns (uint256 collateralRatio) {
        LoopStrategyStorage.Layout storage $ = LoopStrategyStorage.layout();

        // TODO: waiting for the rebalanceTo function
        // return RebalanceLogic.rebalanceTo(
        //     $.lendingPool,
        //     $.strategyAssets,
        //     loanState,
        //     targetRatio,
        //     $.oracle,
        //     $.swapper
        // );

        return RebalanceLogic.rebalanceDown(
            $.lendingPool,
            $.strategyAssets,
            loanState,
            targetRatio,
            $.oracle,
            $.swapper
        );
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 assets) public view override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        // TODO: static call deposit() and return number of expected shares
    }

    /// @inheritdoc IERC4626
    function mint(uint256 shares, address receiver) public override(ERC4626Upgradeable, IERC4626) whenNotPaused returns (uint256) {
        revert();
        // TODO: we should disable minting exact amount of shares
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 assets, address receiver, address owner) public override(ERC4626Upgradeable, IERC4626) whenNotPaused returns (uint256) {
        // TODO: should we just revert and disable this function also?
        //       possible calculation of shares for given cbETH amount is described in PRD
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 shares, address receiver, address owner) public override(ERC4626Upgradeable, IERC4626) whenNotPaused returns (uint256) {
        // TODO: redeem flow
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 shares) public view override(ERC4626Upgradeable, IERC4626) returns (uint256) {
        // TODO: static call redeem() and return the expected withdrawal amount
    }

    /// @dev returns if collateral ratio is out of the acceptable range and reabalance should happen
    /// @param collateralRatio given collateral ratio
    /// @param collateraRatioTargets struct which contain targets (min and max for rebalance)
    function _shouldRebalance(uint256 collateralRatio, CollateralRatio memory collateraRatioTargets) internal returns(bool) {
        return (collateralRatio < collateraRatioTargets.minForRebalance || collateralRatio > collateraRatioTargets.maxForRebalance);
    }


    // TODO: copied from RebalanceLogic, should be part of the usdLib?

    /// @notice helper function to calculate collateral ratio
    /// @param collateralUSD collateral value in USD
    /// @param debtUSD debt valut in USD
    /// @return ratio collateral ratio value
    function _collateralRatioUSD(uint256 collateralUSD, uint256 debtUSD)
        internal
        pure
        returns (uint256 ratio)
    {
        ratio = debtUSD != 0 ? USDWadMath.usdDiv(collateralUSD, debtUSD) : 0;
    }
}