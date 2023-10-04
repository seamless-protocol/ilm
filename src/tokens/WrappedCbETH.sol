// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { IERC20, ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IWrappedERC20PermissionedDeposit} from "../interfaces/IWrappedERC20PermissionedDeposit.sol";

contract WrappedCbETH is IWrappedERC20PermissionedDeposit, ERC20, Ownable2Step {

    IERC20 private immutable _underlying;
    mapping(address => bool) depositor;

    modifier onlyDepositors {
      if (!depositor[msg.sender]) {
        revert NotDepositor(msg.sender);
      }
      _;
    }

    constructor(
      string memory _name, 
      string memory _symbol, 
      IERC20 _underlyingToken
    ) ERC20(_name, _symbol) Ownable() {
      _underlying = _underlyingToken;
    }

    function underlying() external override view returns (address) {
      return address(_underlying);
    }

    function deposit(uint256 amount) external override onlyDepositors {
      SafeERC20.safeTransferFrom(_underlying, msg.sender, address(this), amount);
      _mint(msg.sender, amount);
      emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external override {
      _burn(msg.sender, amount);
      SafeERC20.safeTransfer(_underlying, msg.sender, amount);
      emit Withdraw(msg.sender, amount);
    }

    function setDepositPermission(address account, bool toSet) external override onlyOwner {
      depositor[account] = toSet;
      emit SetDepositPermission(account, toSet);
    }

    function recover() external override onlyOwner {
      uint256 amountSurplus = _underlying.balanceOf(address(this)) - totalSupply();
      SafeERC20.safeTransfer(_underlying, msg.sender, amountSurplus);
      emit RecoverUnderlyingSurplus(msg.sender, amountSurplus);
    }
}

