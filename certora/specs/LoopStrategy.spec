
import "CVLMath.spec";

using LoopStrategyHarness as _LoopStrategy;

methods {


    // Pool:

    //using under-approx. for refuting. Todo: remove
    function _.getUserAccountData(address user) external => DISPATCHER(true);
//    function _.getUserAccountData(address user) external   => CONSTANT;
//    function _.getUserAccountData(address user) external   => getUserAccountData_nondet(user) expect (uint256,uint256,uint256,uint256,uint256,uint256);
//    function _.getUserAccountData(address user) external   => getUserAccountData_ones(user) expect (uint256,uint256,uint256,uint256,uint256,uint256);

    function equity() external returns (uint256) envfree;
    function equityUSD() external returns (uint256) envfree;
    function debt() external returns (uint256) envfree;
    function collateral() external returns (uint256) envfree;
    function currentCollateralRatio() external returns (uint256) envfree;
    function totalSupply() external returns (uint256) envfree;


    // Swapper
    function _.swap(address, address, uint256, address payable) external => CONSTANT; // NONDET;
    function _.offsetFactor(address, address) external => CONSTANT; //NONDET;

    //ERC4626Upgradeable
    function _._withdraw(address, address,address, uint256 ,uint256) internal => NONDET;

    //ERC20Upgradeable
    function _._mint(address, uint256) internal => NONDET;

    // function _.supply(address, uint256, address, uint16) external => DISPATCHER(true); 
    // function _.repay(address, uint256, uint256, address) external => DISPATCHER(true);
    // function _.withdraw(address, uint256, address) external => DISPATCHER(true);
     function _.getReserveData(address) external => CONSTANT;
    // function _.borrow(address, uint256, uint256, uint16, address) external => DISPATCHER(true);
    // function _.getReserveNormalizedVariableDebt(address) external => DISPATCHER(true);

    function decimals() external returns uint8 envfree;
    // ERC20Metadata
    //function _.name() external => DISPATCHER(true);
    //function _.symbol() external => DISPATCHER(true);
    function _.decimals() external => const_decimals() expect uint256;
    //function _.getDecimals() external => const_decimals() expect uint256;

    
/*

    // IERC20
    function _.approve(address, uint256) external => DISPATCHER(true);
    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);

*/
    // PriceOracle
    //function _.setAssetPrice(address, uint256) external => DISPATCHER(true);
    function _.getAssetPrice(address) external => CONSTANT;



/*
    // IVariableDebtToken
    function _.scaledTotalSupply() external => DISPATCHER(true);


    // IACLManager
    function _.isPoolAdmin(address) external => DISPATCHER(true);


    // IPoolAddressProvider // breaks the prover if AAVE pool is added
    //function _.getACLManager() external => DISPATCHER(true);

    // IAaveIncentivesController  // implemented only in MockIncentivesController as an empty function
    // function _.handleAction(address, uint256, uint256) external => DISPATCHER(true)

*/
    // ISwapAdapter
    function _.executeSwap(address, address, uint256, address payable) external => DISPATCHER(true);

    /*
        Summarizations for deposit function
    */
    // function _.rebalanceAfterSupply(address storage, address memory, uint256) external => emptyFunction() expect void;

    // function _.safeTransferFrom(address token, address from, address to, uint256 amount) internal => emptyFunction() expect void;

    // function updateState(Storage.Layout storage)    public
    //     returns (LoanState memory state)

    // function _._deposit(uint256, address, uint256) external => depositSummarization() expect (uint256);
    // function _._deposit(uint256, address, uint256) internal => depositSummarization() expect (uint256);


   // function USDWadRayMath.usdDiv(uint256, uint256) internal returns (uint256);

    // /LoopStrategyHarness
    function usdDivMock(uint256 a, uint256 b) external returns (uint256) envfree;
    function usdMulMock(uint256 a, uint256 b) external returns (uint256) envfree;


    // MathSummarizations
    //Formal-friendly summarries of multiple and divide
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


//LoanLogic.getMaxBorrowUSD: (,, uint256 availableBorrowsUSD,,,) = lendingPool.pool.getUserAccountData(address(this));
//function getUserAccountData(address) external PoolLogic.executeGetUserAccountData(


function const_decimals() returns uint256 {return 10; }
 function getUserAccountData_nondet(address user) returns (uint256,uint256,uint256,uint256,uint256,uint256) 
{
        return (_, _, _, _, _, _);
}
 
 function getUserAccountData_ones(address user) returns (uint256,uint256,uint256,uint256,uint256,uint256) 
{
        return (1, 1, 1, 1, 1, 1);
}


// function emptyFunction() {
//     assert true;
// }

// function depositSummarization() returns uint256 {
//     return 10;
// }


definition disabledFunction(method f) returns bool = 
    f.selector == sig:_LoopStrategy.mint(uint256, address).selector ||
    f.selector == sig:_LoopStrategy.maxMint(address).selector ||
    f.selector == sig:_LoopStrategy.previewMint(uint256).selector ||
    f.selector == sig:_LoopStrategy.withdraw(uint256, address, address).selector ||
    f.selector == sig:_LoopStrategy.previewWithdraw(uint256).selector ||
    f.selector == sig:_LoopStrategy.maxWithdraw(address).selector;
/*    f.selector == sig:VariableDebtToken.transferFrom(address, address, uint256).selector ||
    f.selector == sig:VariableDebtToken.mint(address,address,uint256,uint256).selector ||
    f.selector == sig:VariableDebtToken.transfer(address, uint256).selector ||
    f.selector == sig:VariableDebtToken.allowance(address, address).selector ||
    f.selector == sig:VariableDebtToken.approve(address, uint256).selector ||
    f.selector == sig:VariableDebtToken.increaseAllowance(address, uint256).selector ||
    f.selector == sig:VariableDebtToken.decreaseAllowance(address, uint256).selector;
*/
definition timeoutingSanity(method f) returns bool = 
    f.selector == sig:_LoopStrategy.deposit(uint256, address).selector ||
    f.selector == sig:_LoopStrategy.deposit(uint256, address, uint256).selector;





rule rebalance_not_needed_after_rebalance
{
    env e1; env e2;
     require decimals() == 15;
    rebalance(e1);
    assert !rebalanceNeeded(e2);
}

rule rebalance_not_needed_after_rebalance__nonzero_debt
{
    env e1; env e2;
    require debt() != 0;
    require decimals() == 15;
    rebalance(e1);
    assert !rebalanceNeeded(e2);
}

rule rebalance_not_needed_after_rebalance__nonzero_debt_4000_12000_100
{
    env e1; env e2;
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
    rebalance(e);
    satisfy !rebalanceNeeded(e);
}


// rule rebalance_not_needed_after_rebalance
// {
//     env e;
//     storage init = lastStorage;
//     rebalance(e);
//     rebalance(e);

//     assert !rebalanceNeeded(e);
// }

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
//filtered { f -> !disabledFunction(f)} 
filtered { f -> !disabledFunction(f) && !timeoutingSanity(f)} 
{
    env e; calldataarg arg;
       require decimals() == 17;
    f(e, arg);
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


rule equity_per_share_non_decreasing {
    env e1; env e2;

    uint256 equityUSD_before;
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

rule equity_per_share_non_decreasing_2 {
    env e1; env e2;

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

    // require to_mathint(x) * 10 ^ 8 == to_mathint(y) * to_mathint(z);
