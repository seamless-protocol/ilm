// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { IOracleMock } from "./IOracleMock.sol";

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

    IOracleMock public oracle;

    constructor(address _collateralAsset, address _borrowAsset, uint256 _maxLTV, address _oracleMock) {
        collateralAsset = IERC20(_collateralAsset);
        borrowAsset = IERC20(_borrowAsset);
        maxLTV = _maxLTV;
        oracle = IOracleMock(_oracleMock);
    }

    /// @notice borrows an amount of borrowAsset for an account
    /// @param account address of account borrowing
    /// @param amount amount being borrowed
    function borrow(address account, uint256 amount) public {
        _enforceLTV(account, amount);
        borrowAsset.transfer(account, amount);
        debt[account] += amount * oracle.getAssetPrice(address(borrowAsset));
    }
    
    /// @notice supplies an amount of collateralAsset for an account
    /// @param account address of account supplying
    /// @param amount amount being supplied
    function supply(address account, uint256 amount) public {
        IERC20(borrowAsset).transfer(account, amount);
        collateral[account] += amount * oracle.getAssetPrice(address(collateralAsset));
    }

    /// @notice repays an amount of debt for an account
    /// @param account address of account repaying
    /// @param amount amount being repaid
    function repay(address account, uint256 amount) public {

        if(debt[account] < amount * oracle.getAssetPrice(address(borrowAsset))) {
            amount = debt[account] / oracle.getAssetPrice(address(borrowAsset));
        }

        borrowAsset.transferFrom(account, address(this), amount);

        debt[account] -= amount * oracle.getAssetPrice(address(borrowAsset));
    }

    /// @notice withdraws an amount of collateralAsset for an account
    /// @param account address of account withdrawing
    /// @param amount amount being withdrawn
    function withdraw(address account, uint256 amount) public {
        _enforceSufficientCollateral(account, amount);
        collateralAsset.transfer(account, amount);
        collateral[account] -= amount * oracle.getAssetPrice(address(collateralAsset));
    }

    /// @notice calculate the maximum amount of value which can be borrowed, in USD for
    /// an account
    /// @param account address of account
    /// @return USD maximum borrow amount
    function maxBorrowAvailable(address account) public view returns (uint256) {
        if (collateral[account] * maxLTV / BASIS > debt[account]) {
            return ((collateral[account] * maxLTV / BASIS) - debt[account]);
        } else {
            return 0;
        }
        
    }

    /// @notice calculate the maximum amount of value which can be withdrawn, in USD for
    /// an account
    /// @param account address of account
    /// @return USD maximum withdraw amount
    function maxWithdrawAvailable(address account) public view returns (uint256) {
        if (collateral[account] > (debt[account] * BASIS / maxLTV)) {
            return collateral[account] - (debt[account] *  BASIS / maxLTV);
        } else {
            return 0;
        }
    }
    
    /// @notice enforces that the LTV is not exceeded when borrowing
    /// @param account address of account borrowing
    /// @param borrowAmount amount being borrowed
    function _enforceLTV(address account, uint256 borrowAmount) internal view {
        if (debt[account] != 0) {
            require(
                ((debt[account] + borrowAmount) * BASIS) / collateral[account] <= maxLTV,
                "LTV exceeded"
            );
        }
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
