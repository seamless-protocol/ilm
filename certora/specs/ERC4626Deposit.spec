import "methods.spec";

methods {

    //Summaries
    function LoopStrategy._convertToShares(uint256, uint256) internal returns (uint256) => NONDET;
    function _.updateState(LoopStrategyStorage.Layout) external => NONDET;
}

// Deposit function increases the receiver’s balance by the shares amount it returns 
//  if the total supply is greater than or equal to the receiver’s balance.
rule depositIncreasesBalanceCorrectly(env e){
    uint256 assets;
    address receiver;
    uint256 minSharesReceived;
    uint256 shares;
    uint256 totalSupply  = totalSupply();
    uint256 _balance = balanceOf(receiver);
    // to avoid the violation coming from the invalid state where totalSupply is < balance
    require totalSupply >= _balance;
    
    shares = deposit(e, assets, receiver, minSharesReceived);
 
    uint256 balance_ = balanceOf(receiver);

    assert _balance + shares == to_mathint(balance_),
    "balance of receiver should increase my the amount of shares returned by deposit";
}