import "methods.spec";

methods {
    
    //Summaries
    function _.rebalanceBeforeWithdraw(LoopStrategyStorage.Layout, uint256, uint256) external => NONDET;
    function LoopStrategy._convertCollateralToUnderlyingAsset(LoopStrategyHarness.StrategyAssets storage, uint256) internal returns (uint256) => NONDET;

}


// Redeem function reduces the share balance of owner by the share amount specified while calling the function
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
