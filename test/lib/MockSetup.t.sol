// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import { BorrowPoolMock } from "../mock/BorrowPoolMock.sol";
import { ERC20Mock } from "../mock/ERC20Mock.sol";
import { OracleMock } from "../mock/OracleMock.sol";
import { SwapperMock } from "../mock/SwapperMock.sol";
import { CollateralRatio } from "../../src/types/DataTypes.sol";

import 'forge-std/Test.sol';

abstract contract MockSetup is Test {

    /// @dev ERC20 mock contracts used as collateral/borrow assets
    ERC20Mock public collateralAsset;
    ERC20Mock public borrowAsset;
    /// @dev mock contract for oracle
    OracleMock public oracle;
    /// @dev mock contract for swapper
    SwapperMock public swapper;
    /// @dev mock contract for borrowing/lending pool
    BorrowPoolMock public borrowPool;

    uint256 internal constant BASIS = 1e8;
    uint256 internal constant LTV = 8e7;

    uint256 internal constant MINT_AMOUNT = 100000 ether;

    CollateralRatio public collateralRatio;

    function setUp() public virtual {
        // deploy instances of mock ERC20 contracts as collateral/borrow assets
        collateralAsset = new ERC20Mock('Collateral Asset', 'CA');
        borrowAsset = new ERC20Mock('Borrow Asset', 'BA');

        // deploy mock oracle instance
        oracle = new OracleMock(address(collateralAsset), address(borrowAsset));

        assert(
             address(oracle.borrowAsset()) == address(borrowAsset)
        );
        assert(
             address(oracle.collateralAsset()) == address(collateralAsset)
        );

        // deploy mock swapper instance
        swapper = new SwapperMock(address(collateralAsset), address(borrowAsset), address(oracle));

        assert(
             address(swapper.borrowAsset()) == address(borrowAsset)
        );
        assert(
             address(swapper.collateralAsset()) == address(collateralAsset)
        );

        // deploy mock borrow pool instance
        borrowPool = new BorrowPoolMock(address(collateralAsset), address(borrowAsset), LTV, address(oracle));

        assert(
            address(borrowPool.borrowAsset()) == address(borrowAsset)
        );
        assert(
             address(borrowPool.collateralAsset()) == address(collateralAsset)
        );

        // mint ample amount of collatera/borrow tokens to borrowPool and swapper
        collateralAsset.mint(address(borrowPool), MINT_AMOUNT); 
        borrowAsset.mint(address(borrowPool), MINT_AMOUNT);

        assert(borrowAsset.balanceOf(address(borrowPool)) == MINT_AMOUNT);
        assert(collateralAsset.balanceOf(address(borrowPool)) == MINT_AMOUNT);

        collateralAsset.mint(address(swapper), MINT_AMOUNT);
        borrowAsset.mint(address(swapper), MINT_AMOUNT);

        assert(borrowAsset.balanceOf(address(swapper)) == MINT_AMOUNT);
        assert(collateralAsset.balanceOf(address(swapper)) == MINT_AMOUNT);
        
        // 3x leverage using collateral ratio at 1.5
        collateralRatio.target = 1.5e8;
        collateralRatio.min = 1.0e8;
        collateralRatio.max = 2.0e8;
    }
}