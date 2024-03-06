
import "CVLMath.spec";

using LoopStrategyHarness as _LoopStrategy;
using CollateralERC20 as _CollateralERC20;

methods {

    // envfree
    function equity() external returns (uint256) envfree;
    function equityUSD() external returns (uint256) envfree;
    function debt() external returns (uint256) envfree;
    function collateral() external returns (uint256) envfree;
    function currentCollateralRatio() external returns (uint256) envfree;
    function totalSupply() external returns (uint256) envfree;
    function getCollateralRatioTargets() external returns (LoopStrategyHarness.CollateralRatio) envfree;
    function getRatioMagin() external returns (uint256) envfree;
    function currentCollateralRatio() external returns (uint256) envfree;

    
    //Summaries

    //WrappedERC20PermissionedDeposit
    function _.withdraw(uint256 amount) external => NONDET; 
    
    // Swapper
    function _.swap(address, address, uint256, address payable) external => CONSTANT; 
    function _.offsetFactor(address, address) external => NONDET; //6000000 expect uint256; // TODO: relax

    //ERC4626Upgradeable
    function _._withdraw(address, address,address, uint256 ,uint256) internal => NONDET;

    //ERC20Upgradeable
    function _._mint(address, uint256) internal => NONDET;

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
    //TODO: summarize wadToUSD

}

//Openzeppelin Math.sol
function mulDiv_with_rounding(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) returns uint256
{
     if (assert_uint8(rounding) == 1 || assert_uint8(rounding) == 3)
         return mulDivUpAbstractPlus(x, y, denominator);
    if (assert_uint8(rounding) == 0 || assert_uint8(rounding) == 2)
         return mulDivDownAbstractPlus(x, y, denominator);
    return _;


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


function simplified_getUserAccountData() returns (uint256,uint256,uint256,uint256,uint256,uint256) 
{
        return (
            mulDivDownAbstractPlus(totalCollateralBase, getFixedPrice(), require_uint256(10 ^ getFixedDecimals())),
            getState_debtUSD(),
            availableBorrowsBase, 
            currentLiquidationThreshold,
            _,
            _);
}

//
function getState_debtUSD() returns uint256
{
    return mulDivDownAbstractPlus(totalDebtBase, getFixedPrice(), require_uint256(10 ^ getFixedDecimals()));
}

function getShareDebtUSD(uint256 shares, uint256 totalShares) returns uint256
{
    return mulDivUpAbstractPlus(getState_debtUSD(), shares, totalShares);
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


rule rebalance_not_needed_after_rebalance
{
    env e1; env e2;
    requireInvariant validCollateralRatioTargets();
    require decimals() == 15;
    
    rebalance(e1);
    assert !rebalanceNeeded(e2);
}

rule rebalance_not_needed_after_rebalance__nonzero_debt
{
    env e1; env e2;
    requireInvariant validCollateralRatioTargets();
    require decimals() == 15;
    require debt() != 0;
    
    rebalance(e1);
    assert !rebalanceNeeded(e2);
}

rule rebalance_not_needed_after_rebalance__nonzero_price
{
    env e1; env e2;
    require decimals() == 15;
    requireInvariant validCollateralRatioTargets();
    
    rebalance(e1);
    assert !rebalanceNeeded(e2);
}

rule rebalance_not_needed_after_rebalance__nonzero_debt_4000_12000_100
{
    env e1; env e2;
    requireInvariant validCollateralRatioTargets();
    require debt() == 4000;
    require collateral() == 12000;
    require totalSupply() == 100;

    require debt() != 0;
    require decimals() == 15;
    rebalance(e1);
    assert !rebalanceNeeded(e2);
}

rule rebalance_not_needed_after_rebalance_witness
{
    env e;
    requireInvariant validCollateralRatioTargets();
    rebalance(e);
    satisfy !rebalanceNeeded(e);
}


rule usdMul_summary_self_check
{
    uint256 x; uint256 y; 
    assert usdMulMock(x, y) == mulNearestUSD(x, y);
}

rule usdDiv_summary_self_check
{
    uint256 x; uint256 y; 
    assert usdDivMock(x, y) == divNearestUSD(x, y);
}

rule divDown_summary_self_check
{
    uint256 x; uint256 y;
    require y != 0;
    uint256 z = require_uint256(x / y); 
    assert to_mathint(divDown(x, y)) == to_mathint(x / y);
}

rule usdMul_summary_under_approximation_self_check
{
    uint256 x; uint256 y; 
    uint256 res =  usdMulMock(x, y);
    mulNearestUSD_assertions(x, y, res);
    assert true;

}

rule usdDiv_summary_under_approximation_self_check
{
    uint256 x; uint256 y; 
    uint256 res =  usdDivMock(x, y);
    divNearestUSD_assertions(x, y, res);
    assert true;

}

rule method_reachability(method f) 
filtered { f -> !disabledFunction(f) && !timeoutingSanity(f)} 
{
    env e; calldataarg arg;
       require decimals() == 15;
    f(e, arg);
    satisfy true;
}

rule method_reachability_redeem {
    env e;
    require decimals() == 17;
    uint256 shares; address receiver; address owner;
    redeem(e, shares, receiver, owner);
    satisfy true;
}



rule method_reachability_deposit {
    env e;
       require decimals() == 17;
    uint256 assets ;
    address receiver;
    deposit(e, assets, receiver);
    satisfy true;
}

rule method_reachability_deposit2 {
    env e;
    uint256 assets;
    address receiver;
    uint256 minSharesReceived;
    deposit(e, assets, receiver, minSharesReceived);
    satisfy true;
}

rule method_reachability_rebalanceNeeded {
    env e; calldataarg args;
    rebalanceNeeded(e, args);
    satisfy true;
}

rule equity_per_share_non_decreasing_after_deposit {
    env e1; env e2;

    require decimals() == 15;
    requireInvariant ratioMagin_leq_1usd();
    requireInvariant validCollateralRatioTargets();


    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
    require totalSupply_before != 0;
    mathint equityUSD_per_share_before = to_mathint(equityUSD_before) / to_mathint(totalSupply_before);


    uint256 assets;
    address receiver;
     deposit(e1, assets, receiver);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply();
    require totalSupply_after != 0;
    mathint equityUSD_per_share_after = to_mathint(equityUSD_after) / to_mathint(totalSupply_after);

    assert  equityUSD_per_share_after >= equityUSD_per_share_before;
}

rule equity_per_share_non_decreasing_after_rebalance {
    env e1; env e2;

    require decimals() == 15;
    requireInvariant ratioMagin_leq_1usd();
    requireInvariant validCollateralRatioTargets();


    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
    require totalSupply_before != 0;
    mathint equityUSD_per_share_before = to_mathint(equityUSD_before) / to_mathint(totalSupply_before);


    rebalance(e1);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply();
    require totalSupply_after != 0;
    mathint equityUSD_per_share_after = to_mathint(equityUSD_after) / to_mathint(totalSupply_after);

    assert  equityUSD_per_share_after >= equityUSD_per_share_before;
}

//fail
rule equity_non_decreasing_after_rebalance {
    env e1; env e2;

    require e1.msg.sender != _CollateralERC20;
    require e2.msg.sender != _CollateralERC20;

    require decimals() == 15;
    requireInvariant ratioMagin_leq_1usd();
    requireInvariant validCollateralRatioTargets();


    uint256 equityUSD_before = equityUSD();

    rebalance(e1);

    uint256 equityUSD_after = equityUSD();

    assert  equityUSD_after >= equityUSD_before;
}

rule total_supply_stable_after_rebalance {
    env e1; env e2;

    require decimals() == 15;
    requireInvariant ratioMagin_leq_1usd();
    requireInvariant validCollateralRatioTargets();


    uint256 totalSupply_before = totalSupply();
    

    rebalance(e1);

    uint256 totalSupply_after = totalSupply();
    
    assert  totalSupply_after == totalSupply_before;
}


rule equity_per_share_non_decreasing {
    env e1; env e2;

    require decimals() == 15;
    requireInvariant ratioMagin_leq_1usd();
    requireInvariant validCollateralRatioTargets();


    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
    require totalSupply_before != 0;
    mathint equityUSD_per_share_before = to_mathint(equityUSD_before) / to_mathint(totalSupply_before);

    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require totalSupply_after != 0;
    mathint equityUSD_per_share_after = to_mathint(equityUSD_after) / to_mathint(totalSupply_after);

    assert  equityUSD_per_share_after >= equityUSD_per_share_before;
}
rule equity_per_share_non_decreasing_100 {
    env e1; env e2;

    requireInvariant ratioMagin_leq_1usd();
    requireInvariant validCollateralRatioTargets();


    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
    require totalSupply_before != 0;
    mathint equityUSD_per_share_before = to_mathint(equityUSD_before) / to_mathint(totalSupply_before);

    
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = require_uint256(totalSupply_before - shares_to_redeem);
    require totalSupply_after != 0;
    mathint equityUSD_per_share_after = to_mathint(equityUSD_after) / to_mathint(totalSupply_after);

    
    require equityUSD_before == 150;
    require totalSupply_before == 30;
    assert  equityUSD_per_share_after >= equityUSD_per_share_before;
}

rule equity_per_share_non_decreasing_100_mul__avoid_C2_H2 {
    env e1; env e2;

    requireInvariant ratioMagin_leq_1usd();
    requireInvariant validCollateralRatioTargets();

    //require !rebalanceNeeded(e1);


    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
    require totalSupply_before != 0;
    uint256 equity_before = equity();
    uint256 debt_before = debt();
    uint256 collateral_before = collateral();

    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    
    require getState_debtUSD() != getShareDebtUSD(shares_to_redeem, totalSupply_before);
    
    
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require totalSupply_after > 0;
    uint256 equity_after = equity();    
    uint256 debt_after = debt();
    uint256 collateral_after = collateral();
    require equityUSD_before == 600;
    require totalSupply_before == 150;
    require shares_to_redeem == 50;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}


rule equity_per_share_non_decreasing_100_mul {
    env e1; env e2;

    requireInvariant ratioMagin_leq_1usd();
    requireInvariant validCollateralRatioTargets();

    require !rebalanceNeeded(e1);


    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
    require totalSupply_before != 0;
    uint256 equity_before = equity();
    uint256 debt_before = debt();
    uint256 collateral_before = collateral();

    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require totalSupply_after > 0;
    uint256 equity_after = equity();    
    uint256 debt_after = debt();
    uint256 collateral_after = collateral();
    require equityUSD_before == 600;
    require totalSupply_before == 150;
    require shares_to_redeem == 50;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}

rule equity_per_share_non_decreasing_100_mul_no_debt_1 {
    env e1; env e2;

    requireInvariant ratioMagin_leq_1usd();
    requireInvariant validCollateralRatioTargets();

    require !rebalanceNeeded(e1);


    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
    require totalSupply_before != 0;
    uint256 equity_before = equity();
    uint256 debt_before = debt();
    require debt_before != 0;
    uint256 collateral_before = collateral();

    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require totalSupply_after > 0;
    uint256 equity_after = equity();    
    uint256 debt_after = debt();
    uint256 collateral_after = collateral();
    require equityUSD_before == 600;
    require totalSupply_before == 150;
    require shares_to_redeem == 50;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}

rule equity_per_share_non_decreasing_100_mul_no_debt_rebalance_not_needed {
    env e1; env e2;

    requireInvariant ratioMagin_leq_1usd();
    requireInvariant validCollateralRatioTargets();
    require e2.msg.sender != _CollateralERC20;

    require !rebalanceNeeded(e1);
    require debt() != 0;


    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
    //require totalSupply_before != 0;
    
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require totalSupply_after > 0;
        
    // require equityUSD_before == 600;
    // require totalSupply_before == 150;
    // require shares_to_redeem == 50;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}

rule equity_per_share_non_decreasing_100_mul_no_debt_rebalance_not_needed__positive_target {
    env e1; env e2;

    requireInvariant ratioMagin_leq_1usd();
    requireInvariant validCollateralRatioTargets();
    require e2.msg.sender != _CollateralERC20;

    require !rebalanceNeeded(e1);
    require debt() != 0;
    require getCollateralRatioTargets().target > 0;


    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
    //require totalSupply_before != 0;
    
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require totalSupply_after > 0;
        
    // require equityUSD_before == 600;
    // require totalSupply_before == 150;
    // require shares_to_redeem == 50;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}

rule equity_per_share_non_decreasing_100_mul_no_debt__cr_eq_target__positive_target__avoid_C2_H2 {
    env e1; env e2;

    requireInvariant ratioMagin_leq_1usd();
    requireInvariant validCollateralRatioTargets();
    require e2.msg.sender != _CollateralERC20;

    require currentCollateralRatio() ==  getCollateralRatioTargets().target;
    require debt() != 0;
    require getCollateralRatioTargets().target > 0;
  uint256 equity_before = equity();

    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    //uint256 equity_before = equity();
    
    uint256 totalSupply_before = totalSupply();
    //require totalSupply_before != 0;
    
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    require getState_debtUSD() != getShareDebtUSD(shares_to_redeem, totalSupply_before);
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);
  uint256 equity_after = equity();
    uint256 equityUSD_after = equityUSD();
    //uint256 equity_after = equity();
    //uint256 wrong_totalSupply_after = totalSupply();

    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require totalSupply_after > 0;
        
    require equityUSD_before == 600;
    require totalSupply_before == 150;
    require shares_to_redeem == 50;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}


rule equity_per_share_non_decreasing_100_mul_no_debt__cr_eq_target__positive_target {
    env e1; env e2;

    requireInvariant ratioMagin_leq_1usd();
    requireInvariant validCollateralRatioTargets();
    require e2.msg.sender != _CollateralERC20;

    require currentCollateralRatio() ==  getCollateralRatioTargets().target;
    require debt() != 0;
    require getCollateralRatioTargets().target > 0;
  uint256 equity_before = equity();

    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    //uint256 equity_before = equity();
    
    uint256 totalSupply_before = totalSupply();
    //require totalSupply_before != 0;
    
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);
  uint256 equity_after = equity();
    uint256 equityUSD_after = equityUSD();
    //uint256 equity_after = equity();
    //uint256 wrong_totalSupply_after = totalSupply();

    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require totalSupply_after > 0;
        
    require equityUSD_before == 600;
    require totalSupply_before == 150;
    require shares_to_redeem == 50;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}

rule equity_per_share_non_decreasing_100_mul_no_debt__cr_eq_target__positive_target_fixed_values {
    env e1; env e2;

    requireInvariant ratioMagin_leq_1usd();
    requireInvariant validCollateralRatioTargets();
    require e2.msg.sender != _CollateralERC20;

    require currentCollateralRatio() ==  getCollateralRatioTargets().target;
    require getCollateralRatioTargets().target == 5100000000;
    require getCollateralRatioTargets().minForRebalance == 0;
    require getCollateralRatioTargets().maxForRebalance == 5100000000;
    require getCollateralRatioTargets().minForWithdrawRebalance == 0;
    require getCollateralRatioTargets().maxForDepositRebalance == 0;
    require debt() == 12;
    require getCollateralRatioTargets().target > 0;


    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 equity_before = equity();
    
    uint256 totalSupply_before = totalSupply();
    //require totalSupply_before != 0;
    
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    uint256 equity_after = equity();
    //uint256 wrong_totalSupply_after = totalSupply();

    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require totalSupply_after > 0;
        
    require equityUSD_before == 600;
    require totalSupply_before == 150;
    require shares_to_redeem == 50;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}

rule equity_per_share_non_decreasing_100_mul_no_debt {
    env e1; env e2;

    requireInvariant ratioMagin_leq_1usd();
    requireInvariant validCollateralRatioTargets();
    require debt() != 0;

    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
    require totalSupply_before != 0;
    
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require totalSupply_after > 0;
        
    require equityUSD_before == 600;
    require totalSupply_before == 150;
    require shares_to_redeem == 50;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}

//fail
rule equity_per_share_non_decreasing_100_mul_fail {
    env e1; env e2;

    requireInvariant ratioMagin_leq_1usd();
    requireInvariant validCollateralRatioTargets();


    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
    require totalSupply_before != 0;
    //mathint equityUSD_per_share_before = to_mathint(equityUSD_before) / to_mathint(totalSupply_before);

    
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require totalSupply_after > 0;
    
    require equityUSD_before == 600;
    require totalSupply_before == 150;
    require shares_to_redeem == 50;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}

rule equity_per_share_non_decreasing_2 {
    env e1; env e2;

    requireInvariant ratioMagin_leq_1usd();
    requireInvariant validCollateralRatioTargets();

    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
    require totalSupply_before != 0;
    mathint equityUSD_per_share_before = to_mathint(equityUSD_before) / to_mathint(totalSupply_before);

    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    uint256 totalSupply_after = totalSupply();
    require totalSupply_after != 0;
    mathint equityUSD_per_share_after = to_mathint(equityUSD_after) / to_mathint(totalSupply_after);

    assert  equityUSD_per_share_after >= equityUSD_per_share_before;
}

rule assets_redeemed_leq_deposited_less_shared {
    env e1; env e2;
    require decimals() == 17;
    uint256 assets_deposited;
    address receiver;
    uint256 minSharesReceived;
    uint256 shares_minted = deposit(e1, assets_deposited, receiver, minSharesReceived);

    uint256 shares_to_redeem;
    address receiver_r;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    assert  shares_to_redeem <= shares_minted => assets_redeeemed <= assets_deposited;
}

rule assets_redeemed_leq_deposited_less_shared_90_20 {
    env e1; env e2;
    require decimals() == 17;
    uint256 assets_deposited;
    address receiver;
    uint256 minSharesReceived;
    uint256 shares_minted = deposit(e1, assets_deposited, receiver, minSharesReceived);

    uint256 shares_to_redeem;
    address receiver_r;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    require shares_minted == 90;
    require shares_to_redeem == 20;

    assert  shares_to_redeem <= shares_minted => assets_redeeemed <= assets_deposited;
}

rule assets_redeemed_leq_deposited_less_shared_4000_12000_100_10_6 {
    env e1; env e2;
    require decimals() == 17;
    require debt() == 4000;
    require collateral() == 12000;
    require totalSupply() == 100;
    
    uint256 assets_deposited;
    address receiver;
    uint256 minSharesReceived;
    uint256 shares_minted = deposit(e1, assets_deposited, receiver, minSharesReceived);

    uint256 shares_to_redeem;
    address receiver_r;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    
    require shares_minted == 10;
    require shares_to_redeem == 6;
    require assets_deposited == 15; 
    assert  shares_to_redeem <= shares_minted => assets_redeeemed <= assets_deposited;
}

rule assets_redeemed_leq_deposited_less_shared_4000_12000_100_10_6_6 {
    env e1; env e2;
    require decimals() == 17;
    require debt() == 4000;
    require collateral() == 12000;
    require totalSupply() == 100;
    
    uint256 assets_deposited;
    address receiver;
    uint256 minSharesReceived;
    uint256 shares_minted = deposit(e1, assets_deposited, receiver, minSharesReceived);

    uint256 shares_to_redeem;
    address receiver_r;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    
    require shares_minted == 10;
    require shares_to_redeem == 6;
    require assets_deposited == 15; 
    assert  assets_redeeemed <= 6;
}


rule assets_redeemed_leq_deposited_less_shared_90_20_15_6 {
    env e1; env e2;
    require decimals() == 17;
    uint256 assets_deposited;
    address receiver;
    uint256 minSharesReceived;
    uint256 shares_minted = deposit(e1, assets_deposited, receiver, minSharesReceived);

    uint256 shares_to_redeem;
    address receiver_r;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    require minSharesReceived == 0;
    require minUnderlyingAsset == 0;
    require shares_minted == 90;
    require shares_to_redeem == 20;
    require assets_deposited == 15; 
    assert  assets_redeeemed != 6;
}

rule assets_redeemed_leq_deposited {
    env e1; env e2;
    require decimals() == 17;
    uint256 assets_deposited;
    address receiver;
    uint256 minSharesReceived;
    uint256 shares = deposit(e1, assets_deposited, receiver, minSharesReceived);

    address receiver_r;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares, receiver, owner, minUnderlyingAsset);

    assert assets_redeeemed <= assets_deposited;
}

rule assets_redeemed_leq_deposited_sanity {
    env e1; env e2;
    require decimals() == 17;
    uint256 assets_deposited;
    address receiver;
    uint256 minSharesReceived;
    uint256 shares = deposit(e1, assets_deposited, receiver, minSharesReceived);

    address receiver_r;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares, receiver, owner, minUnderlyingAsset);

    assert to_mathint(assets_redeeemed) <= to_mathint(assets_deposited) + 400;
}


rule redeemed_test_4000_12000_100_10 {
    env e1; env e2;
    require decimals() == 17;
    require debt() == 4000;
    require collateral() == 12000;
    require totalSupply() == 100;
    

    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    require shares_to_redeem == 10;
    require minUnderlyingAsset == 0;

    uint256 debt_after = debt();
    uint256 collateral_after = collateral();
    uint256 totalSupply_after = totalSupply();
    uint256 currentCollateralRatio_after = currentCollateralRatio();
    uint256 equity_after = equity();
    
    assert  false;
}


rule redeem_reverts {
    env e1; env e2;


    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    
    uint256 balance_before = balanceOf(e1, owner);

    uint256 assets_redeeemed = redeem@withrevert(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);
 
 
    assert  balance_before < shares_to_redeem => lastReverted;
}

invariant validCollateralRatioTargets()
        getCollateralRatioTargets().minForRebalance <= getCollateralRatioTargets().target
        && getCollateralRatioTargets().maxForRebalance >= getCollateralRatioTargets().target
        && getCollateralRatioTargets().minForRebalance <= getCollateralRatioTargets().minForWithdrawRebalance
        && getCollateralRatioTargets().maxForRebalance >= getCollateralRatioTargets().maxForDepositRebalance;

invariant ratioMagin_leq_1usd()
        getRatioMagin() <= 10 ^ 8;
