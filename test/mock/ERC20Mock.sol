// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title ERC20Mock
/// @dev ERC20 mock contract 
contract ERC20Mock is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    /// @notice mints an amount of tokens to an address
    /// @param to address to mint to
    /// @param amount amount of tokens to mint
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    /// @notice burn an amount of tokens of an address
    /// @param to address to burn from
    /// @param amount amount of tokens to burn
    function burn(address to, uint256 amount) public {
        _burn(to, amount);
    }
}
