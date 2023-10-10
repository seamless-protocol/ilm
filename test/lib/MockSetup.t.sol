// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import "forge-std/Test.sol";

import { BorrowPoolMock } from "../mock/BorrowPoolMock.sol";
import { ERC20Mock } from "../mock/ERC20Mock.sol";
import { OracleMock } from "../mock/OracleMock.sol";
import { SwapperMock } from "../mock/SwapperMock.sol";

abstract contract MockSetup is Test {

    /// @dev ERC20 mock contracts used as collateral/borrow assets
    IERC20 public collateralAsset;
    IERC20 public borrowAsset;
    /// @dev mock contract for oracle
    OracleMock public oracle;
    /// @dev mock contract for swapper
    SwapperMock public swapper;
    /// @dev mock contract for borrowing/lending pool
    BorrowPoolMock public borrowPool;

    uint256 internal constant BASIS = 1e8;
    uint256 internal constant LTV = 8e7;

    function setUp() public virtual {
        // deploy instances of mock ERC20 contracts as collateral/borrow assets
        collateralAsset = new ERC20Mock('Collateral Asset', 'CA');
        borrowAsset = new ERC20Mock('Borrow Asset', 'BA');

        // deploy mock oracle instance
        oracle = new OracleMock(address(collateralAsset), address(borrowAsset));

        // deploy mock swapper instance
        swapper = new SwapperMock(address(collateralAsset), address(borrowAsset));

        // deploy mock borrow pool instance
        borrowPool = new BorrowPoolMock(address(collateralAsset), address(borrowAsset), LTV);
    }
}