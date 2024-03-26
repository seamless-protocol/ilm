import "methods.spec";

methods {

    //Summaries
    function LoopStrategy._convertToShares(uint256, uint256) internal returns (uint256) => NONDET;
    function _.updateState(LoopStrategyStorage.Layout) external => NONDET;

}

// shares=deposit() increases blanceOf() by shares
// https://prover.certora.com/output/11775/fbb034de2c224040a31c14bfb3be88e2?anonymousKey=3c16920f4defde62c6307421d4c99d3be936586e - beta
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