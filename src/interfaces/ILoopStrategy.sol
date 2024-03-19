// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {
    CollateralRatio,
    LendingPool,
    StrategyAssets
} from "../types/DataTypes.sol";

/// @title IStrategy
/// @notice interface for Integration Liquiity Market strategies
/// @dev interface similar to IERC4626, with some additional functions for health management
interface ILoopStrategy is IERC4626 {
    /// @notice mint function from IERC4626 is disabled
    error MintDisabled();

    /// @notice withdraw function from IERC4626 is disabled
    error WithdrawDisabled();

    /// @notice reverts when rebalance function is called but collateral ratio is in the target range
    error RebalanceNotNeeded();

    /// @notice reverts when attempting to set collateral ratio targets which are not logically consistent
    /// in terms of their values
    error InvalidCollateralRatioTargets();

    /// @notice reverts when shares received by user on deposit is lower than given minimum
    /// @param sharesReceived amount of shares received
    /// @param minSharesReceived minimum defined by caller
    error SharesReceivedBelowMinimum(
        uint256 sharesReceived, uint256 minSharesReceived
    );

    /// @notice thrown when underlying received upon share redemption or asset withdrawing is
    /// less than given minimum limit
    /// @param underlyingReceived amount of underlying received
    /// @param minUnderlyingReceived minimum amount of underlying to receive
    error UnderlyingReceivedBelowMinimum(
        uint256 underlyingReceived, uint256 minUnderlyingReceived
    );

    /// @notice thrown when attempting to set a margin value which is meant to lie between
    /// 0 < margin < 1e8 (1 USD)
    error MarginOutsideRange();

    /// @notice thrown when the caller of the redeem function is not the owner of the
    /// shares to be redeemed
    error RedeemerNotOwner();

    /// @notice emitted when a new value for the collateralRatioTargets is set
    /// @param targets new value of collateralRatioTargest struct
    event CollateralRatioTargetsSet(CollateralRatio targets);

    /// @notice emitted when a new value for maxIterations is set
    /// @param iterations new value for maxIterations
    event MaxIterationsSet(uint16 iterations);

    /// @notice emitted when a new value for ratioMargin is set
    /// @param margin new value for ratioMargin
    event RatioMarginSet(uint256 margin);

    /// @notice emitted when a new value for usdMargin is set
    /// @param margin new value for usdMargin
    event USDMarginSet(uint256 margin);

    /// @notice emitted when a new value for assets cap is set
    /// @param assetsCap new value for assets cap
    event AssetsCapSet(uint256 assetsCap);

    /// @notice emitted when a new value for the swapper address is set
    /// @param swapper new address of swapper contract
    event SwapperSet(address swapper);

    /// @notice returns the amount of equity belonging to the strategy
    /// in underlying token value
    /// @return amount equity amount
    function equity() external view returns (uint256 amount);

    /// @notice returns the amount of equity belonging to the strategy
    /// in USD value
    /// @return amount equity amount
    function equityUSD() external view returns (uint256 amount);

    /// @notice returns the amount of debt belonging to the strategy
    /// in underlying value (USD)
    /// @return amount debt amount
    function debtUSD() external view returns (uint256 amount);

    /// @notice returns the amount of collateral belonging to the strategy
    /// in underlying value (USD)
    /// @return amount collateral amount
    function collateralUSD() external view returns (uint256 amount);

    /// @notice pauses deposits and withdrawals from the contract
    function pause() external;

    /// @notice unpauses deposits and withdrawals from the contract
    function unpause() external;

    /// @notice sets the collateral ratio targets (target ratio, min and max for rebalance,
    /// @notice max for deposit rebalance and min for collateral rebalance)
    /// @param collateralRatioTargets collateral ratio targets struct
    function setCollateralRatioTargets(
        CollateralRatio memory collateralRatioTargets
    ) external;

    /// @notice returns min, max and target collateral ratio values
    /// @return ratio struct containing min, max and target collateral ratio values
    function getCollateralRatioTargets()
        external
        view
        returns (CollateralRatio memory ratio);

    /// @notice sets the interest rate mode for the loan
    /// @param interestRateMode interest rate mode per aave enum InterestRateMode {NONE, STABLE, VARIABLE}
    function setInterestRateMode(uint256 interestRateMode) external;

    /// @notice returns the current collateral ratio value of the strategy
    /// @return ratio current collateral ratio value
    function currentCollateralRatio() external view returns (uint256 ratio);

    /// @notice rebalances the strategy
    /// @dev perofrms a downwards/upwards leverage depending on the current strategy state in order to be
    /// within collateral ratio range
    /// @return ratio value of collateral ratio after strategy rebalances
    function rebalance() external returns (uint256 ratio);

    /// @notice retruns true if collateral ratio is out of the target range, and we need to rebalance pool
    /// @return shouldRebalance true if rebalance is needed
    function rebalanceNeeded() external view returns (bool shouldRebalance);

    /// @notice deposit assets to the strategy with the requirement of shares received
    /// @param assets amount of assets to deposit
    /// @param receiver address of the receiver of share tokens
    /// @param minSharesReceived required minimum of shares received
    /// @return shares number of received shares
    function deposit(
        uint256 assets,
        address receiver,
        uint256 minSharesReceived
    ) external returns (uint256 shares);

    /// @notice redeems an amount of shares by burning shares from the owner, and rewarding the receiver with
    /// the share value
    /// @param shares amount of shares to burn
    /// @param receiver address to receive share value
    /// @param owner address of share owner
    /// @param minUnderlyingAsset minimum amount of underlying asset to receive
    /// @return assets amount of underlying asset received
    function redeem(
        uint256 shares,
        address receiver,
        address owner,
        uint256 minUnderlyingAsset
    ) external returns (uint256 assets);

    /// @notice sets the assets cap value
    /// @param assetsCap new value of assets cap
    function setAssetsCap(uint256 assetsCap) external;

    /// @notice sets the ratioMarginUSD value
    /// @param marginUSD new value of ratioMarginUSD
    function setRatioMargin(uint256 marginUSD) external;

    /// @notice sets the maxIterations value
    /// @param iterations new value of maxIterations
    function setMaxIterations(uint16 iterations) external;

    /// @notice sets the swapper contract address
    /// @param swapper address of swapper contract
    function setSwapper(address swapper) external;

    /// @notice returns underlying StrategyAssets struct
    /// @return assets underlying StrategyAssets struct
    function getAssets() external view returns (StrategyAssets memory assets);

    /// @notice returns poolAddressProvider contract address
    /// @return poolAddressProvider poolAddressProvider contract address
    function getPoolAddressProvider()
        external
        view
        returns (address poolAddressProvider);

    /// @notice returns LendingPool struct
    /// @return pool LendingPool struct
    function getLendingPool() external view returns (LendingPool memory pool);

    /// @notice returns address of oracle contract
    /// @return oracle address of oracle contract
    function getOracle() external view returns (address oracle);

    /// @notice returns address of swapper contract
    /// @return swapper address of swapper contract
    function getSwapper() external view returns (address swapper);

    /// @notice returns value of ratioMargin
    /// @return marginUSD ratioMargin value
    function getRatioMargin() external view returns (uint256 marginUSD);

    /// @notice returns value of maxIterations
    /// @return iterations maxIterations value
    function getMaxIterations() external view returns (uint256 iterations);
}
