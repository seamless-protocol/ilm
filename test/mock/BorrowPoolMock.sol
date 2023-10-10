// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

/// @title BorrowPoolMock
/// @dev BorrowPool mock contract mimicking Aave at a very high level
contract BorrowPoolMock {
    /// @notice ERC20 used for collateral
    IERC20 public collateralAsset;
    /// @notice ERC20 used for debt
    IERC20 public borrowAsset;
    /// @notice debt of an account
    mapping(address account => uint256 amount) public debt;
    /// @notice collateral of an account
    mapping(address account => uint256 amount) public collateral;
    /// @notice max loan-to-value ratio
    uint256 public maxLTV;
    /// @notice BASIS used for basis-point (percentage) calculations
    uint256 public constant BASIS = 1e8;

    constructor(address _collateralAsset, address _borrowAsset, uint256 _maxLTV) {
        collateralAsset = IERC20(_collateralAsset);
        borrowAsset = IERC20(_borrowAsset);
        maxLTV = _maxLTV;
    }

    /// @notice borrows an amount of borrowAsset for an account
    /// @param account address of account borrowing
    /// @param amount amount being borrowed
    function borrow(address account, uint256 amount) public {
        _enforceLTV(account, amount);
        borrowAsset.transfer(account, amount);
        debt[account] += amount;
    }
    
    /// @notice supplies an amount of collateralAsset for an account
    /// @param account address of account supplying
    /// @param amount amount being supplied
    function supply(address account, uint256 amount) public {
        IERC20(borrowAsset).transfer(account, amount);
        collateral[account] += amount;
    }

    /// @notice repays an amount of debt for an account
    /// @param account address of account repaying
    /// @param amount amount being repaid
    function repay(address account, uint256 amount) public {
        if(debt[account] > amount) {
            amount -= (amount - debt[account]);
        }

        borrowAsset.transferFrom(account, address(this), amount);
        debt[account] -= amount;
    }

    /// @notice withdraws an amount of collateralAsset for an account
    /// @param account address of account withdrawing
    /// @param amount amount being withdrawn
    function withdraw(address account, uint256 amount) public {
        _enforceSufficientCollateral(account, amount);
        collateralAsset.transfer(account, amount);
        collateral[account] -= amount;
    }
    
    /// @notice enforces that the LTV is not exceeded when borrowing
    /// @param account address of account borrowing
    /// @param borrowAmount amount being borrowed
    function _enforceLTV(address account, uint256 borrowAmount) internal view {
        require(
            ((debt[account] + borrowAmount) * BASIS) / collateral[account] <= maxLTV,
            "LTV exceeded"
        );
    }

    /// @notice enforces that an account has enough collateral for a withdrawal
    /// @param account address of account withdrawing
    /// @param withdrawAmount amount being withdrawn
    function _enforceSufficientCollateral(address account, uint256 withdrawAmount) internal view {
        require(
            collateral[account] >= withdrawAmount,
            "Insufficient collateral"
        );
    }
}
