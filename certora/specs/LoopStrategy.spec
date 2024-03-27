
//import "CVLMath.spec";
import "methods.spec";

using LoopStrategyHarness as _LoopStrategy;
using CollateralERC20 as _CollateralERC20;

methods {

    // envfree
  
    
    //Summaries

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

//fail https://prover.certora.com/output/99352/c1d3ce3c11df46d3a2b4b903f544273b/?anonymousKey=69700a19c19a893355a1c7ae2cb221c2607e8c51
//https://prover.certora.com/output/99352/21522faae907423889655839aae41fa3/?anonymousKey=0dbd05877adf4bbb1961dee64775d9d84d9ea4bd
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

//fail C-2 https://prover.certora.com/output/99352/d409fd527e90499fb780bb5e32f25291/?anonymousKey=c0e54054afdd020a6979e63937bba9e86e459882
//timeout
//pass with zero slippage
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

    assert  maxSlippagePercent() == 0 => equityUSD_per_share_after >= equityUSD_per_share_before;
}

//pass
rule equity_per_share_non_decreasing_after_rebalance_witness {
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

    satisfy  !(equityUSD_per_share_after >= equityUSD_per_share_before);
}

//fail
//https://prover.certora.com/output/99352/d409fd527e90499fb780bb5e32f25291/?anonymousKey=c0e54054afdd020a6979e63937bba9e86e459882
//https://prover.certora.com/output/99352/51add206b0af43958635ec3628ca8fbc/?anonymousKey=ec98ffa76f17ea6521a77784f08c247d677d2e3e
//pass with zero slippage
//pass
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
    assert  maxSlippagePercent() == 0 => equityUSD_after >= equityUSD_before;
}

//pass
rule equity_non_decreasing_after_rebalance_witness {
    env e1; env e2;

    require e1.msg.sender != _CollateralERC20;
    require e2.msg.sender != _CollateralERC20;

    require decimals() == 15;
    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();
    uint256 equityUSD_before = equityUSD();
    rebalance(e1);
    uint256 equityUSD_after = equityUSD();
    satisfy  !(equityUSD_after >= equityUSD_before);
}


//fail
//https://prover.certora.com/output/99352/758d474a0711482daf27b9f2596728bf/?anonymousKey=473a0da46b85d3cb11672d18c76dca707e956379
// rebalanceDown
// ratio <= targetCR
//target = 200000000
//CR     = 150005000
// collateral = 150005000, debt = 10 ^ 8
// withdraw(949995000)
// swap(049995000) = 049495050
// repay(049495050)
// collaterl = 100010000, debt = 050504950


//
// https://prover.certora.com/output/99352/2a41ff2c1db24d868235e89733638d7f/?anonymousKey=3b00b00ca4c416d1a882734d67edb4e2952fb0c3
// rebalanceUp
//
rule equity_non_decreasing_after_rebalance_witness_twice {
    env e1; env e2;

    require e1.msg.sender != _CollateralERC20;
    require e2.msg.sender != _CollateralERC20;
    require e2.msg.sender != currentContract;

    require decimals() == 15;
    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();
    uint256 equityUSD_before = equityUSD();
    rebalance(e1);
    uint256 equityUSD_after = equityUSD();
    assert  to_mathint( 10^4 + equityUSD_after) >= to_mathint(equityUSD_before);
}

// fail
// https://prover.certora.com/output/99352/27109c1cad1b4ada8670e0eee7cba24e/?anonymousKey=e30439cc1f2474ded6675da29bdbd443a4714443
// CR = 300010499
// target = 9680542449175
rule equity_non_decreasing_after_rebalance_witness_twice_rebalanceDown {
    env e1; env e2;

    require e1.msg.sender != _CollateralERC20;
    require e2.msg.sender != _CollateralERC20;
    require e2.msg.sender != currentContract;

    require decimals() == 15;
    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();
    uint256 equityUSD_before = equityUSD();
    require currentCollateralRatio() <  getCollateralRatioTargets().target;

    rebalance(e1);
    uint256 equityUSD_after = equityUSD();
    assert  to_mathint( 10^8 + equityUSD_after) >= to_mathint(equityUSD_before);
}

rule equity_non_decreasing_after_rebalance_witness_twice_rebalanceUp {
    env e1; env e2;

    require e1.msg.sender != _CollateralERC20;
    require e2.msg.sender != _CollateralERC20;
    require e2.msg.sender != currentContract;

    require decimals() == 15;
    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();
    uint256 equityUSD_before = equityUSD();
    require currentCollateralRatio() > getCollateralRatioTargets().target;

    rebalance(e1);
    uint256 equityUSD_after = equityUSD();
    assert  to_mathint( 10^8 + equityUSD_after) >= to_mathint(equityUSD_before);
}

rule equity_non_decreasing_after_rebalance_witness_rebalanceDown {
    env e1; env e2;

    require e1.msg.sender != _CollateralERC20;
    require e2.msg.sender != _CollateralERC20;
    require e2.msg.sender != currentContract;

    require decimals() == 15;
    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();
    uint256 equityUSD_before = equityUSD();
    require currentCollateralRatio() <  getCollateralRatioTargets().target;

    rebalance(e1);
    uint256 equityUSD_after = equityUSD();
    assert  to_mathint(equityUSD_after) >= to_mathint(equityUSD_before);
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
//fail
//https://prover.certora.com/output/99352/1c0381596b0a47708097737e8a7ab93b/?anonymousKey=4b32e9aceb6d8cc690e4761a25cf1c30835c6aad
//timeout with zero slippage
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
    assert  maxSlippagePercent() == 0 => equityUSD_per_share_after >= equityUSD_per_share_before;
}

rule equity_per_share_non_decreasing_100_witness {
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
    satisfy  !(equityUSD_per_share_after >= equityUSD_per_share_before);
}


//fail splippage10
// https://prover.certora.com/output/99352/467c61b530b34ba78843baead51e9f65/?anonymousKey=ffe0a0f825690bb0b3ee85ac08fae0f52bad15d6
//timeout

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
    assert  maxSlippagePercent() == 0 => equityUSD_per_share_after >= equityUSD_per_share_before;
}
rule equity_per_share_non_decreasing_100__rebalanceNotNeeded_witness {
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
    satisfy !(equityUSD_per_share_after >= equityUSD_per_share_before);
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

//timeout
//pass UNSAT rebalance not needed
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
    assert  maxSlippagePercent() == 0 => equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}

//fail UNSAT rebalance not needed
rule equity_per_share_non_decreasing_100_mul_witness {
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
    satisfy !(equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after);
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
//timeout
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

//pass
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


//pass with zero slippage
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
//https://prover.certora.com/output/99352/a415f6b6b6f14820b32cea290db05b08/?anonymousKey=c074741ee2d2a489e8af4295f0ecff11d54da0eb
//pass with zero slippage

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

//pass 
rule equity_per_share_non_decreasing_100_mul_fail_rebalance_not_needed {
    env e1; env e2;

    requireInvariant ratioMargin_leq_1usd();
    requireInvariant validCollateralRatioTargets();

    require !rebalanceNeeded(e1);

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


//pass - keep (fail if rebalance is needed)
rule equity_per_share_non_decreasing_100_mul_fail_rebalance_not_needed_no_require {
    env e1; env e2;

    //requireInvariant ratioMargin_leq_1usd();
    //requireInvariant validCollateralRatioTargets();

    require !rebalanceNeeded(e1);

    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
    require totalSupply_before != 0;
    
    
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    require shares_to_redeem <= totalSupply_before;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
    require totalSupply_after > 0;
    
    //require equityUSD_before == 600;
    require totalSupply_before == 150;
    require shares_to_redeem == 50;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}


//fail https://prover.certora.com/output/99352/d409fd527e90499fb780bb5e32f25291/?anonymousKey=c0e54054afdd020a6979e63937bba9e86e459882
//https://prover.certora.com/output/99352/21522faae907423889655839aae41fa3/?anonymousKey=0dbd05877adf4bbb1961dee64775d9d84d9ea4bd
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
//https://prover.certora.com/output/99352/f41f40afa3eb4c429dfa53ad0cd70ba7/?anonymousKey=9dcdb67f1bb9c05548f0ece4bbf742e6f315d433
//timeout with zero slippage
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

    assert  maxSlippagePercent() == 0 => shares_to_redeem <= shares_minted => assets_redeeemed <= assets_deposited;
}
rule assets_redeemed_leq_deposited_less_shared_witness {
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

    satisfy !(shares_to_redeem <= shares_minted => assets_redeeemed <= assets_deposited);
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

//reachability check https://prover.certora.com/output/99352/d409fd527e90499fb780bb5e32f25291/?anonymousKey=c0e54054afdd020a6979e63937bba9e86e459882 
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

    
//    assert collateralRatio_before > target => collateralRatio_after <= collateralRatio_before;
    assert collateralRatio_before <= target => collateralRatio_after >= collateralRatio_before;
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

//pass with slippage zero
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
    
    assert maxSlippagePercent() == 0 => equityUSD_after == equityUSD_before;
}

//pass
rule same_equity_after_consecutive_rebalance_witness
{
    env e1; env e2;
    requireInvariant validCollateralRatioTargets();
    requireInvariant ratioMargin_leq_1usd();
    require decimals() == 15;
    
    rebalance(e1);
    uint256 equityUSD_before = equityUSD();
    rebalance(e2);
    uint256 equityUSD_after = equityUSD();
    
    satisfy !(equityUSD_after == equityUSD_before);
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
//timeout
//pass with zero slippage
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
        f -> (f.selector != sig:upgradeToAndCall(address,bytes) .selector)
    }
    {
        preserved LoopStrategy_init(
        string  _erc20name,
        string  _erc20symbol,
        address _initialAdmin,
        LoopStrategyHarness.StrategyAssets  _strategyAssets,
        LoopStrategyHarness.CollateralRatio  _collateralRatioTargets,
        address _poolAddressProvider,
        address _oracle,
        address _swapper,
        uint256 _ratioMargin,
        uint16 _maxIterations) with (env e) 
        {
            require currentCollateralRatio() == 0;
        } 
    }

invariant collateralRatio_leq_minForRebalance_zeroSlippage()
     maxSlippagePercent() == 0 => getCollateralRatioTargets().minForRebalance <= currentCollateralRatio()
      filtered {
        f -> (f.selector != sig:upgradeToAndCall(address,bytes) .selector)
    }
    {
        preserved LoopStrategy_init(
        string  _erc20name,
        string  _erc20symbol,
        address _initialAdmin,
        LoopStrategyHarness.StrategyAssets  _strategyAssets,
        LoopStrategyHarness.CollateralRatio  _collateralRatioTargets,
        address _poolAddressProvider,
        address _oracle,
        address _swapper,
        uint256 _ratioMargin,
        uint16 _maxIterations) with (env e) 
        {
            require currentCollateralRatio() == 0;
        } 
    }

rule collateralRatio_geq_maxForRebalance(method f)
filtered {f -> (f.selector != sig:upgradeToAndCall(address,bytes) .selector)}
{
    require getCollateralRatioTargets().maxForRebalance >= currentCollateralRatio();
    env e; calldataarg args;
    f(e, args);
    assert getCollateralRatioTargets().maxForRebalance >= currentCollateralRatio();
}

rule collateralRatio_geq_maxForRebalance_zeroSlippage(method f)
filtered {f -> (f.selector != sig:upgradeToAndCall(address,bytes) .selector)}
{
    require maxSlippagePercent() == 0 => getCollateralRatioTargets().maxForRebalance >= currentCollateralRatio();
    env e; calldataarg args;
    f(e, args);
    assert maxSlippagePercent() == 0 => getCollateralRatioTargets().maxForRebalance >= currentCollateralRatio();
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
