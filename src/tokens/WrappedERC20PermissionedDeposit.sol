// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.21;

import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC20Metadata } from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IWrappedERC20PermissionedDeposit } from
    "../interfaces/IWrappedERC20PermissionedDeposit.sol";

/// @title WrappedERC20PermissionedDeposit
/// @notice contract used to wrap underlying ERC20 token and mints the same amount of a wrapped token.
/// @notice wrapped token will be used to mainly as a collateral in the lending pool
/// @notice but only strategies contracts will be able to get wrapped token and borrow against it.
contract WrappedERC20PermissionedDeposit is
    IWrappedERC20PermissionedDeposit,
    ERC20,
    AccessControl
{
    /// @dev role which can deposit to this contract to wrap underlying token
    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    /// @notice address of the underlying token which is wrapped
    IERC20 public immutable underlying;

    constructor(
        string memory _name,
        string memory _symbol,
        IERC20 _underlyingToken,
        address _initialAdmin
    ) ERC20(_name, _symbol) {
        underlying = _underlyingToken;
        _grantRole(DEFAULT_ADMIN_ROLE, _initialAdmin);
    }

    /// @inheritdoc ERC20
    function decimals() public view override returns (uint8) {
        return IERC20Metadata(address(underlying)).decimals();
    }

    /// @inheritdoc IWrappedERC20PermissionedDeposit
    function deposit(uint256 amount)
        external
        override
        onlyRole(DEPOSITOR_ROLE)
    {
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
    function recover() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 amountSurplus =
            underlying.balanceOf(address(this)) - totalSupply();
        SafeERC20.safeTransfer(underlying, msg.sender, amountSurplus);
        emit RecoverUnderlyingSurplus(msg.sender, amountSurplus);
    }
}
