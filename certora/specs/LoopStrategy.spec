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
    //requireInvariant validCollateralRatioTargets();
    //requireInvariant ratioMargin_leq_1usd();
    //require decimals() == 15;
    
    rebalance(e1);
    uint256 equityUSD_before = equityUSD();
    rebalance(e2);
    uint256 equityUSD_after = equityUSD();
    
    satisfy !(equityUSD_after == equityUSD_before);
}

// fail
// https://prover.certora.com/output/99352/27109c1cad1b4ada8670e0eee7cba24e/?anonymousKey=e30439cc1f2474ded6675da29bdbd443a4714443
// CR = 300010499
// target = 9680542449175
rule equity_decreasing_after_rebalance_witness_rebalanceDown {
    
    env e; 
    require currentCollateralRatio() <  getCollateralRatioTargets().target;
    uint256 equityUSD_before = equityUSD();
    rebalance(e);
    uint256 equityUSD_after = equityUSD();
    satisfy to_mathint( 10^4 + equityUSD_after) < to_mathint(equityUSD_before);
}

//pass 
// https://prover.certora.com/output/99352/7b83ff97a4af4c0a9d630ecd504a751c/?anonymousKey=05774edfe533c52579100fa7438635f34f44c4d4
rule equity_decreasing_after_rebalance_witness_rebalanceUp {
    env e; 
    require currentCollateralRatio() > getCollateralRatioTargets().target;

    uint256 equityUSD_before = equityUSD();
    rebalance(e);
    uint256 equityUSD_after = equityUSD();
    satisfy to_mathint( 10^8 + equityUSD_after) < to_mathint(equityUSD_before);
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









//pass - keep (fail if rebalance is needed)
//todo rename keep
rule equity_per_share_non_decreasing_100_mul_fail_rebalance_not_needed_no_require {
    env e1; env e2;

    //requireInvariant ratioMargin_leq_1usd();
    //requireInvariant validCollateralRatioTargets();

    require !rebalanceNeeded(e1);

//    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
//    require totalSupply_before != 0;
    
    
    uint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    
//    require shares_to_redeem <= totalSupply_before;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
//    require totalSupply_after > 0;
    
    //require equityUSD_before == 600;
    require totalSupply_before == 150;
    require shares_to_redeem == 50;
    assert  equityUSD_after * totalSupply_before >=  equityUSD_before *  totalSupply_after;
}
//todo: keep rename
rule equity_per_share_non_decreasing_100_mul_fail_rebalance_not_needed_no_require_witness {
    env e1; env e2;

    //requireInvariant ratioMargin_leq_1usd();
    //requireInvariant validCollateralRatioTargets();

//    require !rebalanceNeeded(e1);

    require decimals() == 15;
    uint256 equityUSD_before = equityUSD();
    uint256 totalSupply_before = totalSupply();
//    require totalSupply_before != 0;
    
    
    ƒuint256 shares_to_redeem;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    
    require shares_to_redeem <= totalSupply_before;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    uint256 equityUSD_after = equityUSD();
    mathint totalSupply_after = totalSupply_before - shares_to_redeem;
//    require totalSupply_after > 0;
    
    //require equityUSD_before == 600;
    require totalSupply_before == 150;
    require shares_to_redeem == 50;
    satisfy equityUSD_after * totalSupply_before <  equityUSD_before *  totalSupply_after;
}


//fail https://prover.certora.com/output/99352/d409fd527e90499fb780bb5e32f25291/?anonymousKey=c0e54054afdd020a6979e63937bba9e86e459882
//https://prover.certora.com/output/99352/21522faae907423889655839aae41fa3/?anonymousKey=0dbd05877adf4bbb1961dee64775d9d84d9ea4bd
// rule equity_per_share_non_decreasing_2 {
//     env e1; env e2;

//     require e1.msg.sender != _LoopStrategy;
//  //require !rebalanceNeeded(e1);
//     requireInvariant ratioMargin_leq_1usd();
//     requireInvariant validCollateralRatioTargets();

//     uint256 equityUSD_before = equityUSD();
//     uint256 totalSupply_before = totalSupply();
//     require totalSupply_before != 0;
//     mathint equityUSD_per_share_before = to_mathint(equityUSD_before) / to_mathint(totalSupply_before);

//     uint256 shares_to_redeem;
//     address receiver;
//     address owner;
//     uint256 minUnderlyingAsset;
//     uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

//     uint256 equityUSD_after = equityUSD();
//     mathint totalSupply_after = totalSupply_before - shares_to_redeem;
//     require totalSupply_after != 0;
//     mathint equityUSD_per_share_after = to_mathint(equityUSD_after) / to_mathint(totalSupply_after);

//     assert  equityUSD_per_share_after >= equityUSD_per_share_before;
// }


//timeout https://prover.certora.com/output/99352/e1295fb6488841bba7c8e83058634049/?anonymousKey=07b95c7dd62bfee1179d68197ab0ca12bacdacf9
//fail https://prover.certora.com/output/99352/f35e03f74f4d40debbc08537c58871d9/?anonymousKey=521f66b69400f3eaf5de7552e6ab87b10e1b1b6d
//https://prover.certora.com/output/99352/f41f40afa3eb4c429dfa53ad0cd70ba7/?anonymousKey=9dcdb67f1bb9c05548f0ece4bbf742e6f315d433
//timeout with zero slippage
rule assets_redeemed_leq_deposited_less_shared {
    env e1; env e2;
    require decimals() == 17;


    uint256 totalSupply_before = totalSupply();
    uint256 assets_deposited;
    address receiver;
    uint256 minSharesReceived;
    uint256 shares_minted = deposit(e1, assets_deposited, receiver, minSharesReceived);

    require to_mathint(totalSupply()) >= to_mathint(shares_minted + totalSupply_before);
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
     uint256 totalSupply_before = totalSupply();
    uint256 assets_deposited;
    address receiver;
    uint256 minSharesReceived;
    uint256 shares_minted = deposit(e1, assets_deposited, receiver, minSharesReceived);

    require to_mathint(totalSupply()) >= to_mathint(shares_minted + totalSupply_before);
    uint256 shares_to_redeem;
    address receiver_r;
    address owner;
    uint256 minUnderlyingAsset;
    uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    satisfy !(shares_to_redeem <= shares_minted => assets_redeeemed <= assets_deposited);
}

// rule assets_redeemed_leq_deposited_less_shared_90_20 {
//     env e1; env e2;
//     require decimals() == 17;
//     uint256 assets_deposited;
//     address receiver;
//     uint256 minSharesReceived;
//     uint256 shares_minted = deposit(e1, assets_deposited, receiver, minSharesReceived);

//     uint256 shares_to_redeem;
//     address receiver_r;
//     address owner;
//     uint256 minUnderlyingAsset;
//     uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

//     require shares_minted == 90;
//     require shares_to_redeem == 20;

//     assert  shares_to_redeem <= shares_minted => assets_redeeemed <= assets_deposited;
// }

// rule assets_redeemed_leq_deposited_less_shared_4000_12000_100_10_6 {
//     env e1; env e2;
//     require decimals() == 17;
//     require debtUSD() == 4000;
//     require collateralUSD() == 12000;
//     require totalSupply() == 100;
    
//     uint256 assets_deposited;
//     address receiver;
//     uint256 minSharesReceived;
//     uint256 shares_minted = deposit(e1, assets_deposited, receiver, minSharesReceived);

//     uint256 shares_to_redeem;
//     address receiver_r;
//     address owner;
//     uint256 minUnderlyingAsset;
//     uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    
//     require shares_minted == 10;
//     require shares_to_redeem == 6;
//     require assets_deposited == 15; 
//     assert  shares_to_redeem <= shares_minted => assets_redeeemed <= assets_deposited;
// }

// rule assets_redeemed_leq_deposited_less_shared_4000_12000_100_10_6_6 {
//     env e1; env e2;
//     require decimals() == 17;
//     require debtUSD() == 4000;
//     require collateralUSD() == 12000;
//     require totalSupply() == 100;
    
//     uint256 assets_deposited;
//     address receiver;
//     uint256 minSharesReceived;
//     uint256 shares_minted = deposit(e1, assets_deposited, receiver, minSharesReceived);

//     uint256 shares_to_redeem;
//     address receiver_r;
//     address owner;
//     uint256 minUnderlyingAsset;
//     uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

    
//     require shares_minted == 10;
//     require shares_to_redeem == 6;
//     require assets_deposited == 15; 
//     assert  assets_redeeemed <= 6;
// }

// rule assets_redeemed_leq_deposited_less_shared_50_150 {
//     env e1; env e2;
//     require decimals() == 15;
    
//     uint256 assets_deposited;
//     address receiver;
//     uint256 minSharesReceived;
//     uint256 shares_minted = deposit(e1, assets_deposited, receiver, minSharesReceived);


//     uint256 shares_to_redeem;
//     address receiver_r;
//     address owner;
//     uint256 minUnderlyingAsset;

//     require shares_to_redeem == 50;
//     require totalSupply() == 100;
//     uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

//     assert  shares_to_redeem <= shares_minted => assets_redeeemed <= assets_deposited;

// }


// rule assets_redeemed_leq_deposited_less_shared_90_20_15_6 {
//     env e1; env e2;
//     require decimals() == 17;
//     uint256 assets_deposited;
//     address receiver;
//     uint256 minSharesReceived;
//     uint256 shares_minted = deposit(e1, assets_deposited, receiver, minSharesReceived);

//     uint256 shares_to_redeem;
//     address receiver_r;
//     address owner;
//     uint256 minUnderlyingAsset;
//     uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

//     require minSharesReceived == 0;
//     require minUnderlyingAsset == 0;
//     require shares_minted == 90;
//     require shares_to_redeem == 20;
//     require assets_deposited == 15; 
//     assert  assets_redeeemed != 6;
// }

// // A user cannot redeem more than deposited
// rule assets_redeemed_leq_deposited {
//     env e1; env e2;
//     require decimals() == 17;
//     uint256 assets_deposited;
//     address receiver;
//     uint256 minSharesReceived;
//     uint256 shares = deposit(e1, assets_deposited, receiver, minSharesReceived);

//     address receiver_r;
//     address owner;
//     uint256 minUnderlyingAsset;
//     uint256 assets_redeeemed = redeem(e2, shares, receiver, owner, minUnderlyingAsset);

//     assert assets_redeeemed <= assets_deposited;
// }

//reachability check 
// rule assets_redeemed_leq_deposited_sanity {
//     env e1; env e2;
//     require decimals() == 17;
//     uint256 assets_deposited;
//     address receiver;
//     uint256 minSharesReceived;
//     uint256 shares = deposit(e1, assets_deposited, receiver, minSharesReceived);

//     address receiver_r;
//     address owner;
//     uint256 minUnderlyingAsset;
//     uint256 assets_redeeemed = redeem(e2, shares, receiver, owner, minUnderlyingAsset);

//     assert to_mathint(assets_redeeemed) <= to_mathint(assets_deposited) + 400;
// }

// //reachability check https://prover.certora.com/output/99352/d409fd527e90499fb780bb5e32f25291/?anonymousKey=c0e54054afdd020a6979e63937bba9e86e459882 
// rule redeemed_test_4000_12000_100_10 {
//     env e1; env e2;
//     require decimals() == 17;
//     require debtUSD() == 4000;
//     require collateralUSD() == 12000;
//     require totalSupply() == 100;
    

//     uint256 shares_to_redeem;
//     address receiver;
//     address owner;
//     uint256 minUnderlyingAsset;
//     uint256 assets_redeeemed = redeem(e2, shares_to_redeem, receiver, owner, minUnderlyingAsset);

//     require shares_to_redeem == 10;
//     require minUnderlyingAsset == 0;

//     uint256 debt_after = debtUSD();
//     uint256 collateral_after = collateralUSD();
//     uint256 totalSupply_after = totalSupply();
//     uint256 currentCollateralRatio_after = currentCollateralRatio();
//     uint256 equity_after = equity();
    
//     assert  false;
// }


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


rule rebalance_direction_non_increasing
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
//    assert collateralRatio_before <= target => collateralRatio_after >= collateralRatio_before;
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
//pass with slippage zero
// rule same_equity_after_consecutive_rebalance
// {
//     env e1; env e2;
//     requireInvariant validCollateralRatioTargets();
//     requireInvariant ratioMargin_leq_1usd();
//     require decimals() == 15;
    
//     rebalance(e1);
//     uint256 equityUSD_before = equityUSD();
//     rebalance(e2);
//     uint256 equityUSD_after = equityUSD();
    
//     assert maxSlippagePercent() == 0 => equityUSD_after == equityUSD_before;
// }

//pass


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

// rule same_collateralRatio_after_consecutive_rebalance_self_check_1
// {
//     env e1; env e2;
//     requireInvariant validCollateralRatioTargets();
//     requireInvariant ratioMargin_leq_1usd();
//     require decimals() == 15;
    
//     storage init = lastStorage;
//     rebalance(e1);
//     uint256 collateralRatio_before = currentCollateralRatio();
//     rebalance(e2) at init;
//     uint256 collateralRatio_after = currentCollateralRatio();

//     assert collateralRatio_after == collateralRatio_before;
// }

//fail: TODO: summarize offsetFactor
//timeout
//pass with zero slippage
// rule same_equity_after_consecutive_rebalance_self_check
// {
//     env e1; env e2;
//     requireInvariant validCollateralRatioTargets();
//     requireInvariant ratioMargin_leq_1usd();
//     require decimals() == 15;
    
//     storage init = lastStorage;
//     rebalance(e1);
//     uint256 equityUSD_before = equityUSD();
//     rebalance(e2) at init;
//     uint256 equityUSD_after = equityUSD();
    
//     assert equityUSD_after == equityUSD_before;
// }


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


// invariant collateralRatio_leq_minForRebalance()
//      getCollateralRatioTargets().minForRebalance <= currentCollateralRatio()
//       filtered {
//         f -> (f.selector != sig:upgradeToAndCall(address,bytes) .selector)
//     }
//     {
//         preserved LoopStrategy_init(
//         string  _erc20name,
//         string  _erc20symbol,
//         address _initialAdmin,
//         LoopStrategyHarness.StrategyAssets  _strategyAssets,
//         LoopStrategyHarness.CollateralRatio  _collateralRatioTargets,
//         address _poolAddressProvider,
//         address _oracle,
//         address _swapper,
//         uint256 _ratioMargin,
//         uint16 _maxIterations) with (env e) 
//         {
//             require currentCollateralRatio() == 0;
//         } 
//     }

// //todo: debug fail
// invariant collateralRatio_leq_minForRebalance_zeroSlippage()
//      maxSlippagePercent() == 0 => getCollateralRatioTargets().minForRebalance <= currentCollateralRatio()
//       filtered {
//         f -> (f.selector != sig:upgradeToAndCall(address,bytes) .selector)
//     }
//     {
//         preserved LoopStrategy_init(
//         string  _erc20name,
//         string  _erc20symbol,
//         address _initialAdmin,
//         LoopStrategyHarness.StrategyAssets  _strategyAssets,
//         LoopStrategyHarness.CollateralRatio  _collateralRatioTargets,
//         address _poolAddressProvider,
//         address _oracle,
//         address _swapper,
//         uint256 _ratioMargin,
//         uint16 _maxIterations) with (env e) 
//         {
//             require currentCollateralRatio() == 0;
//         } 
//     }

// rule collateralRatio_geq_maxForRebalance(method f)
// filtered {f -> (f.selector != sig:upgradeToAndCall(address,bytes) .selector)}
// {
//     require getCollateralRatioTargets().maxForRebalance >= currentCollateralRatio();
//     env e; calldataarg args;
//     f(e, args);
//     assert getCollateralRatioTargets().maxForRebalance >= currentCollateralRatio();
// }

// //todo: debug fail
// rule collateralRatio_geq_maxForRebalance_zeroSlippage(method f)
// filtered {f -> (f.selector != sig:upgradeToAndCall(address,bytes) .selector)}
// {
//     require maxSlippagePercent() == 0 => getCollateralRatioTargets().maxForRebalance >= currentCollateralRatio();
//     env e; calldataarg args;
//     f(e, args);
//     assert maxSlippagePercent() == 0 => getCollateralRatioTargets().maxForRebalance >= currentCollateralRatio();
// }

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
