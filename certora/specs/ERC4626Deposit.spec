// import "LoopStrategy.spec";
import "CVLMath.spec";

using LoopStrategyHarness as _LoopStrategy;
using CollateralERC20 as _CollateralERC20;

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

    
    //Summaries
    function LoopStrategy._convertToShares(uint256, uint256) internal returns (uint256) => NONDET;
    function _.updateState(LoopStrategyStorage.Layout) external => NONDET;
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
    function _.getUserAccountData(address user) external   => simplified_getUserAccountData(user) expect (uint256,uint256,uint256,uint256,uint256,uint256);
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
    //TODO: summarize wadToUSD
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
ghost mathint sumUserBalances {
    init_state axiom sumUserBalances == 0;
}


function simplified_getUserAccountData(address user) returns (uint256,uint256,uint256,uint256,uint256,uint256) 
{
        return (
            mulDivDownAbstractPlus(totalCollateralBase, getFixedPrice(), require_uint256(10 ^ getFixedDecimals())),
            mulDivDownAbstractPlus(totalDebtBase, getFixedPrice(), require_uint256(10 ^ getFixedDecimals())),
            availableBorrowsBase, 
            currentLiquidationThreshold,
            _,
            _);
}

function simplified_borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)
{
    totalDebtBase = require_uint256(totalDebtBase + amount);
}

function simplified_repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) returns uint256
{
    if (amount == max_uint256)
        {
            uint256 prev_debt = totalDebtBase;
            totalDebtBase = 0;
            return prev_debt;
        }

    totalDebtBase = require_uint256(totalDebtBase - amount);
    return amount;
}

function simplified_supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)
{
    totalCollateralBase = require_uint256(totalCollateralBase + amount);
}

function simplified_withdraw(address asset, uint256 amount, address to) returns uint256
{
    if (amount == max_uint256)
        {
            uint256 prev_collateral = totalCollateralBase;
            totalCollateralBase = 0;
            return prev_collateral;
        }
    totalCollateralBase = require_uint256(totalCollateralBase - amount);
    return amount;
}



definition disabledFunction(method f) returns bool = 
    f.selector == sig:_LoopStrategy.mint(uint256, address).selector ||
    f.selector == sig:_LoopStrategy.maxMint(address).selector ||
    f.selector == sig:_LoopStrategy.previewMint(uint256).selector ||
    f.selector == sig:_LoopStrategy.withdraw(uint256, address, address).selector ||
    f.selector == sig:_LoopStrategy.previewWithdraw(uint256).selector ||
    f.selector == sig:_LoopStrategy.maxWithdraw(address).selector;

definition timeoutingSanity(method f) returns bool = 
    f.selector == sig:_LoopStrategy.deposit(uint256, address).selector ||
    f.selector == sig:_LoopStrategy.deposit(uint256, address, uint256).selector;


// munging
// ERC20Upgradeable


// shares=deposit() increases blanceOf() by shares
// status: WIP
// https://prover.certora.com/output/11775/9f5a26b334a04430a87792c9bae0f9ac?anonymousKey=70f0deb759a5cc2965f7009263f8fc6cd5a1a340
rule depositIncreasesBalanceCorrectly(env e){
    uint256 assets;
    address receiver;
    uint256 minSharesReceived;
    uint256 shares;
    uint256 totalSupply  = totalSupply();
    uint256 _balance = balanceOf(receiver);
    // to avoid CE in fd1af61d9f. Checking if this is enough for a proof. Refer to invariant userBalanceLeTotalSupply.
    require totalSupply >= _balance;
    
    shares = deposit(e, assets, receiver, minSharesReceived);
 
    uint256 balance_ = balanceOf(receiver);

    assert _balance + shares == to_mathint(balance_),
    "balance of receiver should increase my the amount of shares returned by deposit";
}