
import "CVLMath.spec";

using LoopStrategyHarness as _LoopStrategy;
using CollateralERC20 as _CollateralERC20;

methods {

    // envfree
    function equity() external returns (uint256) envfree;
    function equityUSD() external returns (uint256) envfree;
    function debtUSD() external returns (uint256) envfree;
    function collateralUSD() external returns (uint256) envfree;
    function currentCollateralRatio() external returns (uint256) envfree;
    function totalSupply() external returns (uint256) envfree;
    function getCollateralRatioTargets() external returns (LoopStrategyHarness.CollateralRatio) envfree;
    function getRatioMargin() external returns (uint256) envfree;
  
    
    //Summaries

    // WrappedERC20PermissionedDeposit.sol
    function _.withdraw(uint256 amount) external => NONDET; 
    function _.deposit(uint256 amount) external => NONDET; 
    
    // Swapper
    function _.swap(address, address, uint256, address payable) external => DISPATCHER(true);//M//
    //function _.swap(address, address, uint256, address payable) external => NONDET;
    function _.offsetFactor(address, address) external => CONSTANT; //  NONDET;
    
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
    

    function LoanLogic._getCollateralUSD(LoanLogic.LendingPool memory) internal returns uint256 => getState_collateralUSD();
    
    // ERC20Metadata
    function decimals() external returns uint8 envfree;
    function _.decimals() external => getFixedDecimals() expect uint8;
    
    // IERC20
    function _.approve(address, uint256) external => NONDET;
    function _.balanceOf(address) external => DISPATCHER(true); 
    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => NONDET; //called from Swapper.swap()//M//


    // PriceOracle
    function _.getAssetPrice(address a)  external => getFixedPrice() expect uint256;

    // IVariableDebtToken
    //function _.scaledTotalSupply() external => DISPATCHER(true);

    // IACLManager
    function _.isPoolAdmin(address) external => DISPATCHER(true);

    // ISwapAdapter
//    function _.executeSwap(address from, address to, uint256 fromAmount, address beneficiary) external => zeroSlippageExecuteSwap(from, to, fromAmount, beneficiary) expect uint256;
    function _.executeSwap(address from, address to, uint256 fromAmount, address beneficiary) external => slippage10PercentExecuteSwap(from, to, fromAmount, beneficiary) expect uint256;


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
     if (rounding == Math.Rounding.Ceil || rounding == Math.Rounding.Expand)
         return mulDivUpAbstractPlus(x, y, denominator);

    if (rounding == Math.Rounding.Floor || rounding == Math.Rounding.Trunc)
         return mulDivDownAbstractPlus(x, y, denominator);

    return _;
}

function slippage10PercentExecuteSwap(address from, address to, uint256 fromAmount, address beneficiary) returns uint256 {
    uint256 toAmount;
    //uint256 fromAmountUSD = mulDivDownAbstractPlus(fromAmount, getFixedPrice(), require_uint256(10 ^ getFixedDecimals()));
    require toAmount * 10 <= fromAmount * 11;
    require toAmount * 10 >= fromAmount * 9;

    return toAmount;


}
function zeroSlippageExecuteSwap(address from, address to, uint256 fromAmount, address beneficiary) returns uint256 {

    return fromAmount;
}


ghost uint256 fixedPrice;
function getFixedPrice() returns uint256
{
    //    return fixedPrice;
        return 1000;
}

ghost uint8 fixedDecimals;
function getFixedDecimals() returns uint8
{
        // require fixedDecimals > 1;
        // require fixedDecimals < 25;
        // return fixedDecimals;
        return 3;
}

//
// Helper CVL function
//

// Converts to USD value
function getState_collateralUSD() returns uint256
{
    return mulDivDownAbstractPlus(totalCollateralBase, getFixedPrice(), require_uint256(10 ^ getFixedDecimals()));
}

// Converts to USD value
function getState_debtUSD() returns uint256
{
    return mulDivDownAbstractPlus(totalDebtBase, getFixedPrice(), require_uint256(10 ^ getFixedDecimals()));
}

// Calculates per-share debt
function getShareDebtUSD(uint256 shares, uint256 totalShares) returns uint256
{
    return mulDivUpAbstractPlus(getState_debtUSD(), shares, totalShares);
}

//
// Simplified pool functions
//

// Assumption:
//------------
// Assuming collateral and debt indexes are constant 1
// Assuming a single user
// Assuming fixed price and decimals
// Assuming fixed availableBorrowsBase and currentLiquidationThreshold

ghost uint256 totalCollateralBase;
ghost uint256 totalDebtBase;
ghost uint256 availableBorrowsBase;
ghost uint256 currentLiquidationThreshold;

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



definition disabledFunction(method f) returns bool = 
    f.selector == sig:_LoopStrategy.mint(uint256, address).selector ||
    f.selector == sig:_LoopStrategy.maxMint(address).selector ||
    f.selector == sig:_LoopStrategy.previewMint(uint256).selector ||
    f.selector == sig:_LoopStrategy.withdraw(uint256, address, address).selector ||
    f.selector == sig:_LoopStrategy.previewWithdraw(uint256).selector ||
    f.selector == sig:_LoopStrategy.maxWithdraw(address).selector;



//
// Rules
//

//fail
rule rebalance_not_needed_after_rebalance__nonzero_debt
{
    env e1; env e2;
    requireInvariant validCollateralRatioTargets();
    require decimals() == 15;
    require debtUSD() != 0;
    
    rebalance(e1);
    assert !rebalanceNeeded(e2);
}

//fail C-2
rule equity_per_share_non_decreasing_after_deposit {
    env e1; env e2;

    require decimals() == 15;
    requireInvariant ratioMargin_leq_1usd();
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

//fail C-2 https://prover.certora.com/output/99352/9d5eb9e404e24789ac7d8baa951f352a/?anonymousKey=058004df83228e41ccae9e75286482f60c6652ec
rule equity_per_share_non_decreasing_after_rebalance {
    env e1; env e2;

    require decimals() == 15;
    requireInvariant ratioMargin_leq_1usd();
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
    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();
    uint256 equityUSD_before = equityUSD();
    rebalance(e1);
    uint256 equityUSD_after = equityUSD();
    assert  equityUSD_after >= equityUSD_before;
}



// keep for PR. fail C-2
rule equity_per_share_non_decreasing {
    env e1; env e2;

    require e2.msg.sender != currentContract;

    require decimals() == 15;
    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();

    //require !rebalanceNeeded(e1);

    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
    require totalSupply_before != 0;
    mathint equityUSD_per_share_before = to_mathint(equityUSD_before) / to_mathint(totalSupply_before);

    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    require shares_to_redeem <= totalSupply_before;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require totalSupply_after != 0;
    mathint equityUSD_per_share_after = to_mathint(equityUSD_after) / to_mathint(totalSupply_after);

    assert  equityUSD_per_share_after >= equityUSD_per_share_before;
}

//fail
//pass with zeroSlippage
//https://prover.certora.com/output/99352/6838774d951145b9a07be5b6dbe30f18/?anonymousKey=3108c5957a3ddc5ca2d50e21b8f9f981644545fc
rule equity_per_share_non_decreasing_100 {
    env e1; env e2;

    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();

    //require !rebalanceNeeded(e1);

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


//fail splippage10
// https://prover.certora.com/output/99352/467c61b530b34ba78843baead51e9f65/?anonymousKey=ffe0a0f825690bb0b3ee85ac08fae0f52bad15d6
rule equity_per_share_non_decreasing_100__rebalanceNotNeeded {
    env e1; env e2;

    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();

    require !rebalanceNeeded(e1);

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

//timeout
rule equity_per_share_non_decreasing_100_mul__avoid_C2_H2 {
    env e1; env e2;

    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();

    require !rebalanceNeeded(e1);
    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    
    require getState_debtUSD() != getShareDebtUSD(shares_to_redeem, totalSupply_before);  //avoid bugs C2 and H2
    
    
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}

//timeout
rule equity_per_share_non_decreasing_100_mul__avoid_C2_H2__nonzero_shares {
    env e1; env e2;

    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();

    require !rebalanceNeeded(e1);
    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
   
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    
    require getState_debtUSD() != getShareDebtUSD(shares_to_redeem, totalSupply_before);  //avoid bugs C2 and H2
    
    
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require shares_to_redeem != 0;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}


rule c {
    env e1; env e2;

    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();

    require !rebalanceNeeded(e1);
    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
   
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    
    require getState_debtUSD() != getShareDebtUSD(shares_to_redeem, totalSupply_before);  //avoid bugs C2 and H2
    require shares_to_redeem <= totalSupply_before;
    
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require shares_to_redeem != 0;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}



//timeout with splippage10Percent and require !rebalanceNeeded()


// https://prover.certora.com/output/99352/6838774d951145b9a07be5b6dbe30f18/?anonymousKey=3108c5957a3ddc5ca2d50e21b8f9f981644545fc
rule equity_per_share_non_decreasing_100_mul__avoid_C2_H2__legal_shares__balanced {
    env e1; env e2;

    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();

    require !rebalanceNeeded(e1);
    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
   
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    
    require getState_debtUSD() != getShareDebtUSD(shares_to_redeem, totalSupply_before);  //avoid bugs C2 and H2
    require shares_to_redeem <= totalSupply_before;
    
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require shares_to_redeem != 0;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}
//timeout with splippage10Percent/zeroSlippageExecuteSwap
rule equity_per_share_non_decreasing_100_mul__avoid_C2_H2__legal_shares__on_target {
    env e1; env e2;

    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();

    require currentCollateralRatio() ==  getCollateralRatioTargets().target;
    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
   
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    
    require getState_debtUSD() != getShareDebtUSD(shares_to_redeem, totalSupply_before);  //avoid bugs C2 and H2
    require shares_to_redeem <= totalSupply_before;
    
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require shares_to_redeem != 0;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}



rule equity_per_share_non_decreasing_100_mul__avoid_C2_H2__nonzero_shares__fixed {
    env e1; env e2;

    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();

    require !rebalanceNeeded(e1);


    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
   
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    
    require getState_debtUSD() != getShareDebtUSD(shares_to_redeem, totalSupply_before);  //avoid bugs C2 and H2
    
    
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require shares_to_redeem != 0;
    require to_mathint(equityUSD_before) == to_mathint(2 * totalSupply_before);
    assert  to_mathint(equityUSD_after) >=  to_mathint(2 *  totalSupply_after);
}

//fail C-2
//todo debug fail
// https://prover.certora.com/output/99352/0d36d7a9557a49c6b091d96759e83aa3/?anonymousKey=55284f69deacf19c8ac650cedc607b460998d64e
rule equity_per_share_non_decreasing_100_mul {
    env e1; env e2;

    require e2.msg.sender != currentContract;
    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();

    require !rebalanceNeeded(e1);


    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
    require totalSupply_before != 0;
    uint256 equity_before = equity();
    uint256 debt_before = debtUSD();
    uint256 collateral_before = collateralUSD();

    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require totalSupply_after > 0;
    uint256 equity_after = equity();    
    uint256 debt_after = debtUSD();
    uint256 collateral_after = collateralUSD();
    require equityUSD_before == 600;
    require totalSupply_before == 150;
    require shares_to_redeem == 50;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}

rule equity_per_share_non_decreasing_100_mul_no_debt_1 {
    env e1; env e2;

    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();

    require !rebalanceNeeded(e1);


    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
    require totalSupply_before != 0;
    uint256 equity_before = equity();
    uint256 debt_before = debtUSD();
    require debt_before != 0;
    uint256 collateral_before = collateralUSD();

    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require totalSupply_after > 0;
    uint256 equity_after = equity();    
    uint256 debt_after = debtUSD();
    uint256 collateral_after = collateralUSD();
    require equityUSD_before == 600;
    require totalSupply_before == 150;
    require shares_to_redeem == 50;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}

//fail C2
rule equity_per_share_non_decreasing_100_mul_no_debt_rebalance_not_needed {
    env e1; env e2;

    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();
    require e2.msg.sender != _CollateralERC20;

    require !rebalanceNeeded(e1);
    require debtUSD() != 0;


    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
    
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require totalSupply_after > 0;
        
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}

rule equity_per_share_non_decreasing_100_mul_no_debt_rebalance_not_needed__positive_target {
    env e1; env e2;

    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();
    require e2.msg.sender != _CollateralERC20;

    require !rebalanceNeeded(e1);
    require debtUSD() != 0;
    require getCollateralRatioTargets().target > 0;


    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
    
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require totalSupply_after > 0;
        
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}

rule equity_per_share_non_decreasing_100_mul_no_debt__cr_eq_target__positive_target__avoid_C2_H2 {
    env e1; env e2;

    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();
    require e2.msg.sender != _CollateralERC20;

    require currentCollateralRatio() ==  getCollateralRatioTargets().target;
    require debtUSD() != 0;
    require getCollateralRatioTargets().target > 0;
    uint256 equity_before = equity();

    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    
    uint256 totalSupply_before = totalSupply();
    
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    require getState_debtUSD() != getShareDebtUSD(shares_to_redeem, totalSupply_before);
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);
    uint256 equity_after = equity();
    uint256 equityUSD_after = equityUSD();
    
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require totalSupply_after > 0;
        
    require equityUSD_before == 600;
    require totalSupply_before == 150;
    require shares_to_redeem == 50;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}


rule equity_per_share_non_decreasing_100_mul_no_debt__cr_eq_target__positive_target {
    env e1; env e2;

    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();
    require e2.msg.sender != _CollateralERC20;

    require currentCollateralRatio() ==  getCollateralRatioTargets().target;
    require debtUSD() != 0;
    require getCollateralRatioTargets().target > 0;
    uint256 equity_before = equity();

    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    
    uint256 totalSupply_before = totalSupply();
    
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);
    uint256 equity_after = equity();
    uint256 equityUSD_after = equityUSD();
    
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require totalSupply_after > 0;
        
    require equityUSD_before == 600;
    require totalSupply_before == 150;
    require shares_to_redeem == 50;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}

rule equity_per_share_non_decreasing_100_mul_no_debt__cr_eq_target__positive_target_fixed_values {
    env e1; env e2;

    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();
    require e2.msg.sender != _CollateralERC20;

    require currentCollateralRatio() ==  getCollateralRatioTargets().target;
    require getCollateralRatioTargets().target == 5100000000;
    require getCollateralRatioTargets().minForRebalance == 0;
    require getCollateralRatioTargets().maxForRebalance == 5100000000;
    require getCollateralRatioTargets().minForWithdrawRebalance == 0;
    require getCollateralRatioTargets().maxForDepositRebalance == 0;
    require debtUSD() == 12;
    require getCollateralRatioTargets().target > 0;


    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 equity_before = equity();
    
    uint256 totalSupply_before = totalSupply();
    
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

    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();
    require debtUSD() != 0;

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

    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();


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


//fail https://prover.certora.com/output/99352/9d5eb9e404e24789ac7d8baa951f352a/?anonymousKey=058004df83228e41ccae9e75286482f60c6652ec

rule equity_per_share_non_decreasing_2 {
    env e1; env e2;

    requireInvariant ratioMargin_leq_1usd();
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


//timeout https://prover.certora.com/output/99352/e1295fb6488841bba7c8e83058634049/?anonymousKey=07b95c7dd62bfee1179d68197ab0ca12bacdacf9
//fail https://prover.certora.com/output/99352/f35e03f74f4d40debbc08537c58871d9/?anonymousKey=521f66b69400f3eaf5de7552e6ab87b10e1b1b6d
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
    require debtUSD() == 4000;
    require collateralUSD() == 12000;
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
    require debtUSD() == 4000;
    require collateralUSD() == 12000;
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

// A user cannot redeem more than deposited
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

//reachability check 
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

//reachability check 
rule redeemed_test_4000_12000_100_10 {
    env e1; env e2;
    require decimals() == 17;
    require debtUSD() == 4000;
    require collateralUSD() == 12000;
    require totalSupply() == 100;
    

    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    require shares_to_redeem == 10;
    require minUnderlyingAsset == 0;

    uint256 debt_after = debtUSD();
    uint256 collateral_after = collateralUSD();
    uint256 totalSupply_after = totalSupply();
    uint256 currentCollateralRatio_after = currentCollateralRatio();
    uint256 equity_after = equity();
    
    assert  false;
}


//| collateral ratio - target | doesn’t increase after rebalance
//timeout
rule rebalance_direction
{
    env e1;
    requireInvariant validCollateralRatioTargets();
    requireInvariant ratioMargin_leq_1usd();
    require decimals() == 15;
    //require debtUSD() != 0;
    uint256 target = getCollateralRatioTargets().target;

    uint256 collateralRatio_before = currentCollateralRatio();
    rebalance(e1);
    uint256 collateralRatio_after = currentCollateralRatio();

    
    assert collateralRatio_before > target => collateralRatio_after <= collateralRatio_before;
    assert collateralRatio_before < target => collateralRatio_after >= collateralRatio_before;
    
//    assert abs(collateralRatio_after - target) <= abs(collateralRatio_before - target);
}


//todo: debug fail
//https://prover.certora.com/output/99352/feb1bc62c0db43b4bc55b57565034520/?anonymousKey=d0755387b4abd0f62e908a56094ed7978150b35a
rule distance_from_target_doesnt_increase_after_rebalance__positive_debt
{
    env e1;
    requireInvariant validCollateralRatioTargets();
    requireInvariant ratioMargin_leq_1usd();
    require decimals() == 15;
    require debtUSD() != 0;
    uint256 target = getCollateralRatioTargets().target;

    uint256 collateralRatio_before = currentCollateralRatio();
    rebalance(e1);
    require debtUSD() != 0;
    uint256 collateralRatio_after = currentCollateralRatio();

    
    assert abs(collateralRatio_after - target) <= abs(collateralRatio_before - target);
}

rule distance_from_target_doesnt_increase_after_rebalance_witness
{
    env e1;
    requireInvariant validCollateralRatioTargets();
    requireInvariant ratioMargin_leq_1usd();
    require decimals() == 15;
    uint256 target = getCollateralRatioTargets().target;

    uint256 collateralRatio_before = currentCollateralRatio();
    rebalance(e1);
    uint256 collateralRatio_after = currentCollateralRatio();

    
    satisfy abs(collateralRatio_after - target) > abs(collateralRatio_before - target);
}


rule same_collateralRatio_after_consecutive_rebalance
{
    env e1; env e2;
    requireInvariant validCollateralRatioTargets();
    requireInvariant ratioMargin_leq_1usd();
    require decimals() == 15;
    
    rebalance(e1);
    uint256 collateralRatio_before = currentCollateralRatio();
    rebalance(e2);
    uint256 collateralRatio_after = currentCollateralRatio();

    assert collateralRatio_after == collateralRatio_before;
}

rule same_equity_after_consecutive_rebalance
{
    env e1; env e2;
    requireInvariant validCollateralRatioTargets();
    requireInvariant ratioMargin_leq_1usd();
    require decimals() == 15;
    
    rebalance(e1);
    uint256 equityUSD_before = equityUSD();
    rebalance(e2);
    uint256 equityUSD_after = equityUSD();
    
    assert equityUSD_after == equityUSD_before;
}


// rule same_storage_after_consecutive_rebalance
// {
//     env e1; env e2;
//     requireInvariant validCollateralRatioTargets();
//     requireInvariant ratioMargin_leq_1usd();
//     require decimals() == 15;
    
//     rebalance(e1);
//     storage storage_before = lastStorage;
//     rebalance(e2);
//     storage storage_after = lastStorage;

//     assert storage_after[_CollateralERC20] == storage_before[_CollateralERC20];
// }

rule same_collateralRatio_after_consecutive_rebalance_self_check_1
{
    env e1; env e2;
    requireInvariant validCollateralRatioTargets();
    requireInvariant ratioMargin_leq_1usd();
    require decimals() == 15;
    
    storage init = lastStorage;
    rebalance(e1);
    uint256 collateralRatio_before = currentCollateralRatio();
    rebalance(e2) at init;
    uint256 collateralRatio_after = currentCollateralRatio();

    assert collateralRatio_after == collateralRatio_before;
}

//fail: TODO: summarize offsetFactor
rule same_equity_after_consecutive_rebalance_self_check
{
    env e1; env e2;
    requireInvariant validCollateralRatioTargets();
    requireInvariant ratioMargin_leq_1usd();
    require decimals() == 15;
    
    storage init = lastStorage;
    rebalance(e1);
    uint256 equityUSD_before = equityUSD();
    rebalance(e2) at init;
    uint256 equityUSD_after = equityUSD();
    
    assert equityUSD_after == equityUSD_before;
}


// rule same_collateralRatio_after_consecutive_rebalance_self_check_2
// {
//     env e1; env e2;
//     requireInvariant validCollateralRatioTargets();
//     requireInvariant ratioMargin_leq_1usd();
//     require decimals() == 15;
    
//     storage storage_init = lastStorage;
//     rebalance(e1);
//     storage storage_before = lastStorage;
//     rebalance(e2) at storage_init;
//     storage storage_after = lastStorage;

//     assert storage_after[_LoopStrategy] == storage_before[_LoopStrategy];
// }


//
// Invariants
//


invariant collateralRatio_leq_minForRebalance()
     getCollateralRatioTargets().minForRebalance <= currentCollateralRatio()
      filtered {
        f -> (f.selector != sig:upgradeToAndCall(address,bytes) .selector
         && f.selector != sig:setCollateralRatioTargets(LoopStrategyHarness.CollateralRatio) .selector) // TODO: remove once I-5 is fixed
    }

invariant collateralRatio_geq_maxForRebalance()
     getCollateralRatioTargets().maxForRebalance >= currentCollateralRatio()
      filtered {
        f -> (f.selector != sig:upgradeToAndCall(address,bytes) .selector
        && f.selector != sig:setCollateralRatioTargets(LoopStrategyHarness.CollateralRatio) .selector) // TODO: remove once I-5 is fixed
    }

// collateralRatioTargets are valid
//fail on LoopStrategy_init() - reported bug L3 
invariant validCollateralRatioTargets()
        getCollateralRatioTargets().minForRebalance <= getCollateralRatioTargets().target
        && getCollateralRatioTargets().maxForRebalance >= getCollateralRatioTargets().target
        && getCollateralRatioTargets().minForRebalance <= getCollateralRatioTargets().minForWithdrawRebalance
        && getCollateralRatioTargets().maxForRebalance >= getCollateralRatioTargets().maxForDepositRebalance
        filtered {
        f -> f.selector != sig:upgradeToAndCall(address,bytes) .selector
    }


// rationMargin is less or equla to 1 USD
//fail on LoopStrategy_init() - extension of bug L3 
//https://prover.certora.com/output/99352/9d5eb9e404e24789ac7d8baa951f352a/?anonymousKey=058004df83228e41ccae9e75286482f60c6652ec
invariant ratioMargin_leq_1usd()
        getRatioMargin() <= 10 ^ 8
        filtered {
        f -> f.selector != sig:upgradeToAndCall(address,bytes) .selector
    }





//
// Setup self-check rules
//

rule method_reachability(method f) 
filtered { f -> !disabledFunction(f) } 
{
    env e; calldataarg arg;
    require decimals() == 15;
    f(e, arg);
    satisfy true;
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
