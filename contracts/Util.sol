// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library RandomUtil {
	using SafeMath for uint256;

	function getRandomSeed(
		string memory keyHash,
		address user,
		uint256 nonce
	) internal view returns (uint256) {
		return
			uint256(
				keccak256(
					abi.encodePacked(keyHash, user, nonce, block.timestamp)
				)
			);
	}

	function randomSeededMinMax(
		uint256 min,
		uint256 max,
		uint256 seed
	) internal pure returns (uint256) {
		uint256 diff = max.sub(min).add(1);
		uint256 randomVar = uint256(keccak256(abi.encodePacked(seed))).mod(
			diff
		);
		randomVar = randomVar.add(min);
		return randomVar;
	}

	function combineSeeds(uint256 seed1, uint256 seed2)
		internal
		pure
		returns (uint256)
	{
		return uint256(keccak256(abi.encodePacked(seed1, seed2)));
	}

	function combineSeeds(uint256[] memory seeds)
		internal
		pure
		returns (uint256)
	{
		return uint256(keccak256(abi.encodePacked(seeds)));
	}

	function plusMinus10PercentSeeded(uint256 num, uint256 seed)
		internal
		pure
		returns (uint256)
	{
		uint256 tenPercent = num.div(10);
		return
			num.sub(tenPercent).add(
				randomSeededMinMax(0, tenPercent.mul(2), seed)
			);
	}

	function plusMinus30PercentSeeded(uint256 num, uint256 seed)
		internal
		pure
		returns (uint256)
	{
		uint256 thirtyPercent = num.mul(30).div(100);
		return
			num.sub(thirtyPercent).add(
				randomSeededMinMax(0, thirtyPercent.mul(2), seed)
			);
	}

	function toString(bytes memory data) public pure returns (string memory) {
		bytes memory alphabet = "0123456789abcdef";

		bytes memory str = new bytes(2 + data.length * 2);
		str[0] = "0";
		str[1] = "x";
		for (uint256 i = 0; i < data.length; i++) {
			str[2 + i * 2] = alphabet[uint256(uint8(data[i] >> 4))];
			str[3 + i * 2] = alphabet[uint256(uint8(data[i] & 0x0f))];
		}
		return string(str);
	}
}
