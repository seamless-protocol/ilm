
import "CVLMath.spec";

using LoopStrategyHarness as _LoopStrategy;

methods {


    // Pool:
    // Over-approximation. Todo: refine
    function _.getUserAccountData(address user) external   => getUserAccountData_nondet(user) expect (uint256,uint256,uint256,uint256,uint256,uint256);
//    function _.getUserAccountData(address user) external   => getUserAccountData_ones(user) expect (uint256,uint256,uint256,uint256,uint256,uint256);

    // function _.supply(address, uint256, address, uint16) external => DISPATCHER(true); 
    // function _.repay(address, uint256, uint256, address) external => DISPATCHER(true);
    // function _.withdraw(address, uint256, address) external => DISPATCHER(true);
    // function _.getReserveData(address) external => DISPATCHER(true);
    // function _.borrow(address, uint256, uint256, uint16, address) external => DISPATCHER(true);
    // function _.getReserveNormalizedVariableDebt(address) external => DISPATCHER(true);

/*
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

*/
    // Swapper
    function _.swap(address, address, uint256, address payable) external => DISPATCHER(true);
    function _.offsetFactor(address, address) external => DISPATCHER(true);

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


    //Formal-friendly summarries of multiple and divide
    function _.usdDiv(uint256 value, uint256 percentage) internal => divNearestUSD(value, percentage) expect uint256;
    function _.usdMul(uint256 value, uint256 percentage) internal => mulNearestUSD(value, percentage) expect uint256;
    function _.percentDiv(uint256 value, uint256 percentage) internal => divNearestPercent(value, percentage) expect uint256;
    function _.percentMul(uint256 value, uint256 percentage) internal => mulNearestPercent(value, percentage) expect uint256;


}


//LoanLogic.getMaxBorrowUSD: (,, uint256 availableBorrowsUSD,,,) = lendingPool.pool.getUserAccountData(address(this));
//function getUserAccountData(address) external PoolLogic.executeGetUserAccountData(


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

rule sanity(method f) 
//    filtered { f -> !disabledFunction(f) && !timeoutingSanity(f)} 
{
    env e; calldataarg arg;
    f(e, arg);
    satisfy true;
}




    // require to_mathint(x) * 10 ^ 8 == to_mathint(y) * to_mathint(z);
