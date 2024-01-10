// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;

import {
    Ownable,
    Ownable2Step
} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IWrappedERC20PermissionedDeposit } from
    "../interfaces/IWrappedERC20PermissionedDeposit.sol";

/// @title WrappedCbETH
/// @notice contract used to wrap underlying ERC20 token and mints the same amount of a wrapped token.
/// @notice this contract will be used to mainly to wrap cbETH and use it as a collateral in the lending pool
/// @notice but only strategies contracts will be able to get wrapped token it and borrow against it.
contract WrappedCbETH is
    IWrappedERC20PermissionedDeposit,
    ERC20,
    Ownable2Step
{
    /// @notice address of the underlying token which is wrapped
    IERC20 public immutable underlying;

    /// @notice map shows if address has pemission to wrap tokens
    mapping(address => bool) public depositor;

    modifier onlyDepositors() {
        if (!depositor[msg.sender]) {
            revert NotDepositor(msg.sender);
        }
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        IERC20 _underlyingToken,
        address _initialOwner
    ) ERC20(_name, _symbol) Ownable(_initialOwner) {
        underlying = _underlyingToken;
    }

    /// @inheritdoc IWrappedERC20PermissionedDeposit
    function deposit(uint256 amount) external override onlyDepositors {
        SafeERC20.safeTransferFrom(
            underlying, msg.sender, address(this), amount
        );
        _mint(msg.sender, amount);
        emit Deposit(msg.sender, amount);
    }

    /// @inheritdoc IWrappedERC20PermissionedDeposit
    function withdraw(uint256 amount) external override {
        _burn(msg.sender, amount);
        SafeERC20.safeTransfer(underlying, msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }

    /// @inheritdoc IWrappedERC20PermissionedDeposit
    function setDepositPermission(address account, bool toSet)
        external
        override
        onlyOwner
    {
        depositor[account] = toSet;
        emit SetDepositPermission(account, toSet);
    }

    /// @inheritdoc IWrappedERC20PermissionedDeposit
    function recover() external override onlyOwner {
        uint256 amountSurplus =
            underlying.balanceOf(address(this)) - totalSupply();
        SafeERC20.safeTransfer(underlying, msg.sender, amountSurplus);
        emit RecoverUnderlyingSurplus(msg.sender, amountSurplus);
    }
}
