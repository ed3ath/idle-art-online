// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title SimpleToken
 * @dev Very simple ERC20 Token example, where all tokens are pre-assigned to the creator.
 * Note they can later distribute these tokens as they wish using `transfer` and other
 * `ERC20` functions.
 * Based on https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v2.5.1/contracts/examples/SimpleToken.sol
 */
contract CorTest is ERC20 {
	/**
	 * @dev Constructor that gives msg.sender all of existing tokens.
	 */
	constructor() ERC20("Idle Art Online Cor", "IAOCOR") {
		_mint(address(this), 1000000 * (10**uint256(decimals())));
		_approve(address(this), msg.sender, totalSupply());
	}
}
