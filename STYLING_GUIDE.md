# Purpose of the Guide

The aim of this styling guide is to establish a unified coding style for creating and maintaining smart contracts for the Seamless contract suites. By adhering to a common style, we can ensure that our smart contracts are easy to read, understand, and collaborate on. This will foster a more efficient and productive development environment, enhancing the quality and reliability of our code.

## Ideal Outcomes

- Readability Increase
- Maintainability Increase
- Error reduction

All of the above 3 points converge towards making our lives easier - from reviewing PRs or picking up where someone left off.

## General Practice

When writing EVM smart contracts we follow the latest [Solidity Style Guide](https://soliditylang.org/docs/style-guide.html), unless indicated otherwise.

When developing using the Foundry testing kit we follow the [recommended best practices](https://book.getfoundry.sh/tutorials/best-practices?highlight=best%20p#tests) for test naming. In particular:

- For numbers in some format, add a suffix with that format. For example, with USD or basis points:
  - `uint256 valueUSD` as opposed to `uint256 value`
  - `uint32 valueBP` as opposed to `uint32 value`

- Event naming for setters should be “Value” + “Set”. For example when setting a variable called protocolFeeBP:
  - `emit ProtocolFeeBPSet(_newValueBP);`

- Ordering imports should go from “closest” to “furthest” conceptually, in alphabetical order if they are in the same “distance”. For example:
  ```
  import { ERC20 } from "@openzeppeling/contracts/ERC20.sol";
  import { IERC20 } from "@openzeppeling/contracts/IERC20.sol";
  import { ContractA } from "./ContractA.sol";
  import { ContractB } from "../oneLevelUp/ContractB.sol";
  ```

- Err on the side of commenting more rather than less! Code is written once and read 1000 times! A simple one-liner above some `if` clause can increase readability/comprehension tremendously!

- The rule of thumb with naming conventions is clarity over brevity; the ideal being clarity _with_ brevity.

- Name return variables

- Add `_` prefix for function parameters, and internal function names:
    - `function _someFunc(uint256 _uintParam) internal returns (address depositor);`

- Nit: Use the same “voice” (active or passive) across comments

- Test function naming as :
  - `test_FuncName_Effect`: `test_deposit_emitsDepositEvent()`
- Fuzz testing as:
  - `testFuzz_FuncName_Effect`: `testFuzz_setFeeBP_setNewFeeValue(uint32 feeBP)`
- Test function reversion cases as : `test_FunctName_RevertsWhen_ReversionContext`
  - `test_setFeeBP_RevertsWhen_CallerIsNotOwner()`

## Comment Styling
When using Foundry, we opt for triple slash as opposed to asterisk commenting. For example:
```solidity
///@notice returns the value    <= what we opt for
/**
 * @notice returns the value    <= not what we opt for
 */
 ```


## Additional Material:
- [Simple Security Toolkit](https://github.com/nascentxyz/simple-security-toolkit)
- [Solcurity](https://github.com/transmissions11)
