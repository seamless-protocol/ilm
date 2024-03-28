import "methods.spec";

using LoopStrategyHarness as _LoopStrategy;
using CollateralERC20 as _CollateralERC20;

methods {

    // WrappedERC20PermissionedDeposit.sol
    function _.deposit(uint256 amount) external => NONDET; 
    
    //ERC4626Upgradeable
    function _._withdraw(address, address,address, uint256 ,uint256) internal => NONDET;

    //ERC20Upgradeable
    function _._mint(address, uint256) internal => NONDET;

    // Pool:
    function LoanLogic._getCollateralUSD(LoanLogic.LendingPool memory) internal returns uint256 => getState_collateralUSD();

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

//pass
rule same_equity_after_rebalance {
    env e; 
    uint256 equityUSD_before = equityUSD();
    rebalance(e);
    uint256 equityUSD_after = equityUSD();
    assert  maxSlippagePercent() == 0 => equityUSD_after == equityUSD_before;
}

rule same_equity_after_rebalance_rebalance_not_needed {
    env e1; env e2;

    require !rebalanceNeeded(e1);
    uint256 equityUSD_before = equityUSD();
    rebalance(e2);
    uint256 equityUSD_after = equityUSD();
    assert equityUSD_after != equityUSD_before;
}

rule same_equity_after_consecutive_rebalance_witness
{
    env e1; env e2;
    
    rebalance(e1);
    uint256 equityUSD_before = equityUSD();
    rebalance(e2);
    uint256 equityUSD_after = equityUSD();
    
    satisfy !(equityUSD_after == equityUSD_before);
}

rule equity_decreasing_after_rebalance_witness_rebalanceDown {
    
    env e; 
    require currentCollateralRatio() <  getCollateralRatioTargets().target;
    uint256 equityUSD_before = equityUSD();
    rebalance(e);
    uint256 equityUSD_after = equityUSD();
    satisfy to_mathint( 10^4 + equityUSD_after) < to_mathint(equityUSD_before);
}

rule equity_decreasing_after_rebalance_witness_rebalanceUp {
    env e; 
    require currentCollateralRatio() > getCollateralRatioTargets().target;

    uint256 equityUSD_before = equityUSD();
    rebalance(e);
    uint256 equityUSD_after = equityUSD();
    satisfy to_mathint( 10^8 + equityUSD_after) < to_mathint(equityUSD_before);
}


rule equity_per_share_non_decreasing {
    env e1; env e2;

    require !rebalanceNeeded(e1);
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
    
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;

    require totalSupply_before == 150;
    require shares_to_redeem == 50;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}

rule equity_per_share_non_decreasing_witness {
    env e1; env e2;

    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
    
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    
    require shares_to_redeem <= totalSupply_before;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require totalSupply_before == 150;
    require shares_to_redeem == 50;
    satisfy equityUSD_after * totalSupply_before <  equityUSD_before *  totalSupply_after;
}


rule rebalance_direction
{
    env e1;
    requireInvariant validCollateralRatioTargets();
    requireInvariant ratioMargin_leq_1usd();
    require decimals() == 15;
    uint256 target = getCollateralRatioTargets().target;

    uint256 collateralRatio_before = currentCollateralRatio();
    rebalance(e1);
    uint256 collateralRatio_after = currentCollateralRatio();

    assert collateralRatio_before <= target => collateralRatio_after >= collateralRatio_before;
}


rule rebalance_direction_non_increasing
{
    env e1;
    requireInvariant validCollateralRatioTargets();
    requireInvariant ratioMargin_leq_1usd();
    require decimals() == 15;
    uint256 target = getCollateralRatioTargets().target;

    uint256 collateralRatio_before = currentCollateralRatio();
    rebalance(e1);
    uint256 collateralRatio_after = currentCollateralRatio();
    
    assert collateralRatio_before > target => collateralRatio_after <= collateralRatio_before;
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

rule same_collateralRatio_after_consecutive_rebalance_zero_slippage
{
    env e1; env e2;
    requireInvariant validCollateralRatioTargets();
    requireInvariant ratioMargin_leq_1usd();
    require decimals() == 15;
    
    rebalance(e1);
    uint256 collateralRatio_before = currentCollateralRatio();
    rebalance(e2);
    uint256 collateralRatio_after = currentCollateralRatio();

    assert maxSlippagePercent() == 0 => collateralRatio_after == collateralRatio_before;
}

//
// Invariants
//



// collateralRatioTargets are valid
invariant validCollateralRatioTargets()
        getCollateralRatioTargets().minForRebalance <= getCollateralRatioTargets().target
        && getCollateralRatioTargets().maxForRebalance >= getCollateralRatioTargets().target
        && getCollateralRatioTargets().minForRebalance <= getCollateralRatioTargets().minForWithdrawRebalance
        && getCollateralRatioTargets().maxForRebalance >= getCollateralRatioTargets().maxForDepositRebalance
        filtered {
        f -> f.selector != sig:upgradeToAndCall(address,bytes) .selector
    }


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
