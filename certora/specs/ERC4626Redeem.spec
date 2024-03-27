import "methods.spec";

methods {
    
    //Summaries
    function _.rebalanceBeforeWithdraw(LoopStrategyStorage.Layout, uint256, uint256) external => NONDET;
    function LoopStrategy._convertCollateralToUnderlyingAsset(LoopStrategyHarness.StrategyAssets storage, uint256) internal returns (uint256) => NONDET;

}

// redeem(shares) reduces blanceof() by shares
// https://prover.certora.com/output/11775/6e5f254b9ae84660b9c5d763d722e020?anonymousKey=e06af2b697e25002e07fc9afa33f0fa82a650cc3 - beta
rule redeemReducesBalanceByShares(env e){
    uint256 shares;
    address receiver;
    address owner;
    uint256 minUnderlyingAsset;
    
    // require owner != currentContract;
    require getERC4626Asset() != currentContract;

    uint256 _balance = balanceOf(owner);
    
    redeem(e, shares, receiver, owner, minUnderlyingAsset);
    
    uint256 balance_ = balanceOf(owner);

    assert balance_ + shares ==  to_mathint(_balance),
    "owner balance should decrease by the amount of shares redeemed";
}
