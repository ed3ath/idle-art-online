// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./Util.sol";

library Common {
	using SafeMath for uint256;
	using SafeMath for uint8;

	function _getRandomStat(
		uint16 minRoll,
		uint16 maxRoll,
		uint256 seed,
		uint256 seed2
	) internal pure returns (uint16) {
		return
			uint16(
				RandomUtil.randomSeededMinMax(
					minRoll,
					maxRoll,
					RandomUtil.combineSeeds(seed, seed2)
				)
			);
	}

	function _getRandomGene(
		uint256 seed,
		uint256 seed2,
		uint8 limit
	) internal pure returns (uint8) {
		return
			uint8(
				RandomUtil.randomSeededMinMax(
					0,
					limit,
					RandomUtil.combineSeeds(seed, seed2)
				)
			);
	}

	function _getRandomGender(uint256 seed, uint256 seed2)
		internal
		pure
		returns (uint8)
	{
		return
			uint8(
				RandomUtil.randomSeededMinMax(
					0,
					100,
					RandomUtil.combineSeeds(seed, seed2)
				)
			) < 50
				? 1
				: 0;
	}

	function _getMinStat(uint8 rarity) internal pure returns (uint16) {
		if (rarity == 0) return 5;
		if (rarity == 1) return 15;
		if (rarity == 2) return 30;
		if (rarity == 3) return 60;
		return 120;
	}

	function _getMaxStat(uint8 rarity) internal pure returns (uint16) {
		if (rarity == 0) return 14;
		if (rarity == 1) return 29;
		if (rarity == 2) return 59;
		if (rarity == 3) return 119;
		return 150;
	}
}
