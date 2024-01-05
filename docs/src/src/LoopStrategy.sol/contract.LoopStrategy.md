# LoopStrategy
[Git Source](https://github.com/seamless-protocol/ilm/blob/48784a426e4cb443b1c1c50d60f0a500ac8f6c1a/src/LoopStrategy.sol)

**Inherits:**
[ILoopStrategy](/src/interfaces/ILoopStrategy.sol/interface.ILoopStrategy.md), ERC4626Upgradeable, Ownable2StepUpgradeable, PausableUpgradeable

Integrated Liquidity Market strategy for amplifying the cbETH staking rewards


## Functions
### LoopStrategy_init


```solidity
function LoopStrategy_init(
    address _initialOwner,
    StrategyAssets memory _strategyAssets,
    CollateralRatio memory _collateralRatioTargets,
    IPoolAddressesProvider _poolAddressProvider,
    IPriceOracleGetter _oracle,
    ISwapper _swapper,
    uint256 _ratioMargin,
    uint16 _maxIterations
) external initializer;
```

### pause


```solidity
function pause() external onlyOwner;
```

### unpause


```solidity
function unpause() external onlyOwner;
```

### setInterestRateMode

sets the interest rate mode for the loan


```solidity
function setInterestRateMode(uint256 _interestRateMode)
    external
    override
    onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_interestRateMode`|`uint256`||


### setCollateralRatioTargets

sets the collateral ratio targets (target ratio, min and max for rebalance,


```solidity
function setCollateralRatioTargets(
    CollateralRatio memory _collateralRatioTargets
) external override onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_collateralRatioTargets`|`CollateralRatio`||


### getCollateralRatioTargets

returns min, max and target collateral ratio values


```solidity
function getCollateralRatioTargets()
    external
    view
    override
    returns (CollateralRatio memory ratio);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`CollateralRatio`|struct containing min, max and target collateral ratio values|


### equityUSD

returns the amount of equity belonging to the strategy
in USD value


```solidity
function equityUSD() public view override returns (uint256 amount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|equity amount|


### equity

returns the amount of equity belonging to the strategy
in underlying token value


```solidity
function equity() public view override returns (uint256 amount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|equity amount|


### debt

returns the amount of debt belonging to the strategy
in underlying value (USD)


```solidity
function debt() external view override returns (uint256 amount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|debt amount|


### collateral

returns the amount of collateral belonging to the strategy
in underlying value (USD)


```solidity
function collateral() external view override returns (uint256 amount);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|collateral amount|


### currentCollateralRatio

returns the current collateral ratio value of the strategy


```solidity
function currentCollateralRatio()
    external
    view
    override
    returns (uint256 ratio);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`uint256`|current collateral ratio value|


### rebalance

rebalances the strategy

*perofrms a downwards/upwards leverage depending on the current strategy state in order to be
within collateral ratio range*


```solidity
function rebalance() external override whenNotPaused returns (uint256 ratio);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`uint256`|value of collateral ratio after strategy rebalances|


### rebalanceNeeded

retruns true if collateral ratio is out of the target range, and we need to rebalance pool


```solidity
function rebalanceNeeded()
    public
    view
    override
    returns (bool shouldRebalance);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shouldRebalance`|`bool`|true if rebalance is needed|


### totalAssets


```solidity
function totalAssets()
    public
    view
    override(ERC4626Upgradeable, IERC4626)
    returns (uint256);
```

### deposit


```solidity
function deposit(uint256 assets, address receiver)
    public
    override(ERC4626Upgradeable, IERC4626)
    whenNotPaused
    returns (uint256 shares);
```

### deposit

deposit assets to the strategy with the requirement of shares received


```solidity
function deposit(uint256 assets, address receiver, uint256 minSharesReceived)
    external
    override
    whenNotPaused
    returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|amount of assets to deposit|
|`receiver`|`address`|address of the receiver of share tokens|
|`minSharesReceived`|`uint256`|required minimum of shares received|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|number of received shares|


### previewDeposit


```solidity
function previewDeposit(uint256 assets)
    public
    view
    override(ERC4626Upgradeable, IERC4626)
    returns (uint256);
```

### mint

mint function is disabled because we can't get exact amount of input assets for given amount of resulting shares


```solidity
function mint(uint256, address)
    public
    view
    override(ERC4626Upgradeable, IERC4626)
    whenNotPaused
    returns (uint256);
```

### previewMint

mint function is disabled because we can't get exact amount of input assets for given amount of resulting shares

*returning 0 because previewMint function must not revert by the ERC4626 standard*


```solidity
function previewMint(uint256)
    public
    view
    override(ERC4626Upgradeable, IERC4626)
    whenNotPaused
    returns (uint256);
```

### withdraw


```solidity
function withdraw(uint256 assets, address receiver, address owner)
    public
    override(ERC4626Upgradeable, IERC4626)
    whenNotPaused
    returns (uint256);
```

### redeem


```solidity
function redeem(uint256 shares, address receiver, address owner)
    public
    override(ERC4626Upgradeable, IERC4626)
    whenNotPaused
    returns (uint256);
```

### redeem

redeems an amount of shares by burning shares from the owner, and rewarding the receiver with
the share value


```solidity
function redeem(
    uint256 shares,
    address receiver,
    address owner,
    uint256 minUnderlyingAsset
) public whenNotPaused returns (uint256 assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|amount of shares to burn|
|`receiver`|`address`|address to receive share value|
|`owner`|`address`|address of share owner|
|`minUnderlyingAsset`|`uint256`|minimum amount of underlying asset to receive|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|amount of underlying asset received|


### previewRedeem


```solidity
function previewRedeem(uint256 shares)
    public
    view
    override(ERC4626Upgradeable, IERC4626)
    returns (uint256);
```

### _shouldRebalance

*returns if collateral ratio is out of the acceptable range and reabalance should happen*


```solidity
function _shouldRebalance(
    uint256 collateralRatio,
    CollateralRatio memory collateraRatioTargets
) internal pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`collateralRatio`|`uint256`|given collateral ratio|
|`collateraRatioTargets`|`CollateralRatio`|struct which contain targets (min and max for rebalance)|


### _deposit

deposit assets to the strategy with the requirement of equity received after rebalance


```solidity
function _deposit(uint256 assets, address receiver, uint256 minSharesReceived)
    internal
    returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|amount of assets to deposit|
|`receiver`|`address`|address of the receiver of share tokens|
|`minSharesReceived`|`uint256`|required minimum of equity received|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|number of received shares|


### _redeem

redeems an amount of shares by burning shares from the owner, and rewarding the receiver with
the share value


```solidity
function _redeem(
    uint256 shares,
    address receiver,
    address owner,
    uint256 minUnderlyingAsset
) internal returns (uint256 assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|amount of shares to burn|
|`receiver`|`address`|address to receive share value|
|`owner`|`address`|address of share owner|
|`minUnderlyingAsset`|`uint256`|minimum amount of underlying asset to receive|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|amount of underlying asset received|


### _collateralRatioUSD

helper function to calculate collateral ratio


```solidity
function _collateralRatioUSD(uint256 collateralUSD, uint256 debtUSD)
    internal
    pure
    returns (uint256 ratio);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`collateralUSD`|`uint256`|collateral value in USD|
|`debtUSD`|`uint256`|debt valut in USD|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ratio`|`uint256`|collateral ratio value|


### _convertToShares

function is the same formula as in ERC4626 implementation, but totalAssets is passed as a parameter of the function

we are using this function because totalAssets may change before we are able to calculate asset(equity) amount;

that is because we are calculating assets based on change in totalAssets


```solidity
function _convertToShares(uint256 _assets, uint256 _totalAssets)
    internal
    view
    virtual
    returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_assets`|`uint256`|amount of assets provided|
|`_totalAssets`|`uint256`|amount of total assets which are used in calculation of shares|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|shares|


### _convertUnderlyingToCollateralAsset

converts underlying asset to the collateral asset if those are different


```solidity
function _convertUnderlyingToCollateralAsset(
    StrategyAssets storage assets,
    uint256 collateralAmountAsset
) internal virtual returns (uint256 receivedAssets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`StrategyAssets`|struct which contain underlying asset address and collateral asset address|
|`collateralAmountAsset`|`uint256`|amount of collateral to convert|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`receivedAssets`|`uint256`|amount of received collateral assets|


### _convertCollateralToUnderlyingAsset

unwrap collateral asset to the underlying asset, if those are different


```solidity
function _convertCollateralToUnderlyingAsset(
    StrategyAssets storage assets,
    uint256 collateralAmountAsset
) internal virtual returns (uint256 underlyingAmountAsset);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`StrategyAssets`|struct which contain underlying asset address and collateral asset address|
|`collateralAmountAsset`|`uint256`|amount of collateral asset to unwrap|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`underlyingAmountAsset`|`uint256`|amount of received underlying assets|


### _shareDebtAndEquity

calculates the debt, and equity corresponding to an amount of shares

*collateral corresponding to shares is just sum of debt and equity*


```solidity
function _shareDebtAndEquity(
    LoanState memory state,
    uint256 shares,
    uint256 totalShares
) internal pure returns (uint256 shareDebtUSD, uint256 shareEquityUSD);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`state`|`LoanState`|loan state of strategy|
|`shares`|`uint256`|amount of shares|
|`totalShares`|`uint256`|total supply of shares|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shareDebtUSD`|`uint256`|amount of debt in USD corresponding to shares|
|`shareEquityUSD`|`uint256`|amount of equity in USD corresponding to shares|


### _updatedState

performs a rebalance if necessary and returns the updated state after
the potential rebalance


```solidity
function _updatedState(Storage.Layout storage $)
    internal
    returns (LoanState memory state);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`$`|`Storage.Layout`|Storage.Layout struct|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`state`|`LoanState`|current LoanState of strategy|


