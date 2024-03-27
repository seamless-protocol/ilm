import "CVLMath.spec";

methods {
        // envfree
    function balanceOf(address) external returns (uint256) envfree;
    function equity() external returns (uint256) envfree;
    function equityUSD() external returns (uint256) envfree;
    function debtUSD() external returns (uint256) envfree;
    function collateralUSD() external returns (uint256) envfree;
    function currentCollateralRatio() external returns (uint256) envfree;
    function totalSupply() external returns (uint256) envfree;
    function getCollateralRatioTargets() external returns (LoopStrategyHarness.CollateralRatio) envfree;
    function getRatioMargin() external returns (uint256) envfree;
    function currentCollateralRatio() external returns (uint256) envfree;
    function getERC4626Asset() external returns (address) envfree;
    
    //WrappedERC20PermissionedDeposit
    function _.withdraw(uint256 amount) external => NONDET; 
    
    // Swapper
    function _.swap(address, address, uint256, address payable) external => CONSTANT; 
    function _.offsetFactor(address, address) external => NONDET; //6000000 expect uint256; // TODO: relax

    //ERC4626Upgradeable
    // function _._withdraw(address, address,address, uint256 ,uint256) internal => NONDET;

    //ERC20Upgradeable
    // function _._mint(address, uint256) internal => NONDET;

    // Pool:
    function _.getUserAccountData(address user) external   => simplified_getUserAccountData() expect (uint256,uint256,uint256,uint256,uint256,uint256);
    function _.supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external
            => simplified_supply(asset, amount, onBehalfOf, referralCode) expect void;

    function _.repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) external
             => simplified_repay(asset, amount, interestRateMode, onBehalfOf) expect uint256;

     function _.withdraw(address asset, uint256 amount, address to) external
            => simplified_withdraw(asset, amount, to) expect uint256;

    function _.borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external 
                => simplified_borrow(asset, amount, interestRateMode, referralCode, onBehalfOf) expect void;
    
    function _.getReserveData(address) external => NONDET; //CONSTANT;
    

    // ERC20Metadata
    function decimals() external returns uint8 envfree;
    function _.decimals() external => getFixedDecimals() expect uint8; //NONDET; //10 expect uint256; //toodo: relax
    
    // IERC20
    function _.approve(address, uint256) external => NONDET;
    function _.balanceOf(address) external => DISPATCHER(true); // only DebtERC20.balanceOf() is used
    function _.transfer(address, uint256) external => DISPATCHER(true);


    // PriceOracle
    function _.getAssetPrice(address a)  external => getFixedPrice() expect uint256; //10 ^ 11 expect uint256; //todo: allow any price

    // IVariableDebtToken
    //function _.scaledTotalSupply() external => DISPATCHER(true);

    // IACLManager
    function _.isPoolAdmin(address) external => DISPATCHER(true);

    // ISwapAdapter
    function _.executeSwap(address, address, uint256, address payable) external => DISPATCHER(true);


    // LoopStrategyHarness - required for self sanity checks only
    function usdDivMock(uint256 a, uint256 b) external returns (uint256) envfree;
    function usdMulMock(uint256 a, uint256 b) external returns (uint256) envfree;


    // Math Summarizations - Formal-friendly summarries of multiple and divide
    
    ///Openzeppelin Math.sol
    function _.mulDiv(uint256 x, uint256 y, uint256 denominator) internal => mulDivDownAbstractPlus(x, y, denominator) expect uint256 ALL; 
    function _.mulDiv(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) internal  => mulDiv_with_rounding(x, y, denominator, rounding) expect uint256 ALL;

    function _.mulDivDown(uint256 a, uint256 b, uint256 c) internal => mulDivDownAbstractPlus(a, b, c) expect uint256 ALL;
    function _.rayDiv(uint256 a, uint256 b) internal => divNearestRay(a, b) expect uint256;
    function _.rayMul(uint256 a, uint256 b) internal => mulNearestRay(a, b) expect uint256;
    function _.wadDiv(uint256 a, uint256 b) internal => divNearestWad(a, b) expect uint256;
    function _.wadMul(uint256 a, uint256 b) internal => mulNearestWad(a, b) expect uint256;
    function _.usdDiv(uint256 value, uint256 percentage) internal => divNearestUSD(value, percentage) expect uint256;
    function _.usdMul(uint256 value, uint256 percentage) internal => mulNearestUSD(value, percentage) expect uint256;
    function _.percentDiv(uint256 value, uint256 percentage) internal => divNearestPercent(value, percentage) expect uint256;
    function _.percentMul(uint256 value, uint256 percentage) internal => mulNearestPercent(value, percentage) expect uint256;

}

//Openzeppelin Math.sol
function mulDiv_with_rounding(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) returns uint256
{
     if (assert_uint8(rounding) == 1 || assert_uint8(rounding) == 3)
         return mulDivUpAbstractPlus(x, y, denominator);
    //if (assert_uint8(rounding) == 0 || assert_uint8(rounding) == 2)
         return mulDivDownAbstractPlus(x, y, denominator);
    //return _;


 }

ghost uint256 fixedPrice;
function getFixedPrice() returns uint256
{
//        require fixedPrice == 3262642740619902120717781402938;
        return fixedPrice;
}

ghost uint8 fixedDecimals;
function getFixedDecimals() returns uint8
{
//        require fixedDecimals == 31;
        require fixedDecimals > 1;
        require fixedDecimals < 25;
        return fixedDecimals;
}


ghost uint256 totalCollateralBase;
ghost uint256 totalDebtBase;
ghost uint256 availableBorrowsBase;
ghost  uint256 currentLiquidationThreshold;
ghost uint256 collateralIndex; //TODO: used scaled values. TODO: allow monotonic non-decreasing 
ghost uint256 debtIndex1; //TODO: allow monotonic non-decreasing 

function getState_collateralUSD() returns uint256
{
    return mulDivDownAbstractPlus(totalCollateralBase, getFixedPrice(), require_uint256(10 ^ getFixedDecimals()));
}

function getState_debtUSD() returns uint256
{
    return mulDivDownAbstractPlus(totalDebtBase, getFixedPrice(), require_uint256(10 ^ getFixedDecimals()));
}

function simplified_getUserAccountData() returns (uint256,uint256,uint256,uint256,uint256,uint256) 
{
        require totalCollateralBase >= totalDebtBase;
        require getState_collateralUSD() >= getState_debtUSD();

        return (
            getState_collateralUSD(),
            getState_debtUSD(),
            availableBorrowsBase, 
            currentLiquidationThreshold,
            _,
            _);
}

// increases debt balance
function simplified_borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)
{
    require totalCollateralBase >= totalDebtBase;
    require getState_collateralUSD() >= getState_debtUSD();
    totalDebtBase = require_uint256(totalDebtBase + amount);
    require totalCollateralBase >= totalDebtBase;
    require getState_collateralUSD() >= getState_debtUSD();
    
}

//reduces debt
function simplified_repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) returns uint256
{
    require totalCollateralBase >= totalDebtBase;
    require getState_collateralUSD() >= getState_debtUSD();
    if (amount == max_uint256)
        {
            uint256 prev_debt = totalDebtBase;
            totalDebtBase = 0;
            return prev_debt;
        }

    totalDebtBase = require_uint256(totalDebtBase - amount);
    require totalCollateralBase >= totalDebtBase;
    require getState_collateralUSD() >= getState_debtUSD();
    
    return amount;
}

// increases collaterl balance
function simplified_supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)
{
    require totalCollateralBase >= totalDebtBase;
    require getState_collateralUSD() >= getState_debtUSD();
    totalCollateralBase = require_uint256(totalCollateralBase + amount);
    require totalCollateralBase >= totalDebtBase;
    require getState_collateralUSD() >= getState_debtUSD();
    
}

// reduces collaterl balance
function simplified_withdraw(address asset, uint256 amount, address to) returns uint256
{
    require totalCollateralBase >= totalDebtBase;
    require getState_collateralUSD() >= getState_debtUSD();
    if (amount == max_uint256)
        {
            uint256 prev_collateral = totalCollateralBase;
            totalCollateralBase = 0;
            return prev_collateral;
        }
    totalCollateralBase = require_uint256(totalCollateralBase - amount);
    require totalCollateralBase >= totalDebtBase;
    require getState_collateralUSD() >= getState_debtUSD();
    return amount;
}
