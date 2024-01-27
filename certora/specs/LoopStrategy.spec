
// Deposit functions have to be munged or summarized because they timeout otherwise even for simple sanity rule.

methods {

/*
    // Pool:
    function _.getUserAccountData(address) external => DISPATCHER(true);
    function _.supply(address, uint256, address, uint16) external => DISPATCHER(true); 
    function _.repay(address, uint256, uint256, address) external => DISPATCHER(true);
    function _.withdraw(address, uint256, address) external => DISPATCHER(true);
    function _.getReserveData(address) external => DISPATCHER(true);
    function _.borrow(address, uint256, uint256, uint16, address) external => DISPATCHER(true);
    function _.getReserveNormalizedVariableDebt(address) external => DISPATCHER(true);
*/

    // ERC20Metadata
    function _.name() external => DISPATCHER(true);
    function _.symbol() external => DISPATCHER(true);
    function _.decimals() external => DISPATCHER(true);
    
    // IERC20
    function _.approve(address, uint256) external => DISPATCHER(true);
    function _.transfer(address, uint256) external => DISPATCHER(true);
    function _.transferFrom(address, address, uint256) external => DISPATCHER(true);
    function _.balanceOf(address) external => DISPATCHER(true);


    // PriceOracle
    function _.setAssetPrice(address, uint256) external => DISPATCHER(true);
    function _.getAssetPrice(address) external => DISPATCHER(true);
    
    // Swapper
    function _.swap(address, address, uint256, address payable) external => DISPATCHER(true);
    function _.offsetFactor(address, address) external => DISPATCHER(true);

    // IVariableDebtToken
    function _.scaledTotalSupply() external => DISPATCHER(true);

    // IACLManager
    function _.isPoolManager(address) external => DISPATCHER(true);

    // IPoolAddressProvider
    //function _.getACLManager() external => DISPATCHER(true);

}


definition disabledFunction(method f) returns bool = 
    f.selector == sig:LoopStrategy.mint(uint256, address).selector ||
    f.selector == sig:LoopStrategy.maxMint(address).selector ||
    f.selector == sig:LoopStrategy.previewMint(uint256).selector ||
    f.selector == sig:LoopStrategy.withdraw(uint256, address, address).selector ||
    f.selector == sig:LoopStrategy.previewWithdraw(uint256).selector ||
    f.selector == sig:LoopStrategy.maxWithdraw(address).selector ||
    f.selector == sig:VariableDebtToken.transferFrom(address, address, uint256).selector ||
    f.selector == sig:VariableDebtToken.mint(address,address,uint256,uint256).selector ||
    f.selector == sig:VariableDebtToken.transfer(address, uint256).selector ||
    f.selector == sig:VariableDebtToken.allowance(address, address).selector ||
    f.selector == sig:VariableDebtToken.approve(address, uint256).selector ||
    f.selector == sig:VariableDebtToken.increaseAllowance(address, uint256).selector ||
    f.selector == sig:VariableDebtToken.decreaseAllowance(address, uint256).selector;

definition timeoutingSanity(method f) returns bool = 
    f.selector == sig:LoopStrategy.deposit(uint256, address).selector ||
    f.selector == sig:LoopStrategy.deposit(uint256, address, uint256).selector;

rule sanity(method f) 
    filtered { f -> !disabledFunction(f) && !timeoutingSanity(f)} {
    env e;
    calldataarg arg;
    f(e, arg);
    // assert false;
    satisfy true;
}



rule sanityForDeposit() {
    env e;
    uint256 assets;
    address receiver;
    deposit(e, assets, receiver);
    satisfy true;
}

rule sanityForDeposit2() {
    env e;
    uint256 assets;
    address receiver;
    uint256 minSharesReceived;
    deposit(e, assets, receiver, minSharesReceived);
    satisfy true;
}
