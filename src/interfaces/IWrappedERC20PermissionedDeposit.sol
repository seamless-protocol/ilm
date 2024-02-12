// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

/// @title IWrappedERC20PermissionedDeposit
/// @notice interface for the Wrapper of ERC20 with permissioned deposit
/// @dev Wraps the underlying ERC20 contract and mints the same amount of a wrapped token.
/// @dev Deposits are permissioned but withdrawals are open to any address.
interface IWrappedERC20PermissionedDeposit is IERC20 {
    /// @notice Sender doesn't have a permission to deposit
    /// @param sender sender address
    error NotDepositor(address sender);

    /// @notice Deposit/wrapping underlying token
    /// @param account account doing the deposit
    /// @param amount amount of tokens deposited
    event Deposit(address account, uint256 amount);

    /// @notice Withdraw/unwrapping underlying token
    /// @param account account doing the withdraw
    /// @param amount amount of withdrawn tokens
    event Withdraw(address account, uint256 amount);

    /// @notice Sets deposit permission
    /// @param account account to set permission for
    /// @param toSet flag to give/withdraw pemission
    event SetDepositPermission(address account, bool toSet);

    /// @notice Recovers surplus of underlying token
    /// @param account account which is doing recovering action
    /// @param amountSurplus surplus amount recovored
    event RecoverUnderlyingSurplus(address account, uint256 amountSurplus);

    /// @notice retruns the underlying token address
    /// @return underlyingToken underlying token
    function underlying() external view returns (IERC20 underlyingToken);

    /// @notice deposits underlying tokens and mint the same amount of wrapped tokens
    /// @param amount amount of the tokens to wrap, in wei
    /// @dev only permissioned depositors are allowed to deposit
    function deposit(uint256 amount) external;

    /// @notice burns amount of wrapped tokens and recieves back the underlying token
    /// @param amount amount of the tokens to withdraw, in wei
    function withdraw(uint256 amount) external;

    /// @notice function used to recover underlying tokens sent directly to this contract by mistake
    function recover() external;

    // /// @notice gives or withdraws permission to deposit
    // /// @param account account address to give/withdraw permission
    // /// @param toSet flag set to true to give permission, or false to withdraw permission
    // function setDepositPermission(address account, bool toSet) external;
}
