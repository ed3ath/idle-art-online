// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./Util.sol";
import "./Common.sol";

contract Equipments is
	Initializable,
	ERC721Upgradeable,
	AccessControlUpgradeable
{
	using SafeMath for uint256;
	using SafeMath for uint8;

	// struct
	struct Equipment {
		uint256 id;
		uint8 rarity;
		uint8 slot;
		uint8 gender;
		uint256 timestamp;
	}

	struct EquipmentAttributes {
		uint16 CHA;
		uint16 CON;
		uint16 DEX;
		uint16 INT;
		uint16 PER;
		uint16 STR;
	}

	// variables
	bytes32 public constant GAME_MASTER = keccak256("GAME_MASTER");

	Equipment[] public equipments;

	string private keyHash;

	// mappings
	mapping(uint256 => EquipmentAttributes) attributes;

	// events
	event NewEquipment(
		address indexed owner,
		uint256 id,
		uint8 rarity,
		uint8 slot,
		uint8 gender,
		EquipmentAttributes attributes,
		uint256 timestamp
	);

	// modifiers
	modifier isAdmin() {
		require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin");
		_;
	}

	modifier restricted() {
		require(hasRole(GAME_MASTER, msg.sender), "Not game master");
		_;
	}

	// private functions
	function _mintEquipment(
		address _minter,
		uint8 _slot,
		uint8 _gender,
		uint256 _tokenID
	) internal restricted {
		if (_tokenID == 0) {
			equipments.push(Equipment(0, 0, 0, 0, 0));
			_tokenID += 1;
		}
		uint8 _rarity;

		uint256 seed = RandomUtil.getRandomSeed(keyHash, _minter, _tokenID);
		uint256 raritySeed = RandomUtil.randomSeededMinMax(
			1,
			1000,
			uint8(seed % block.timestamp)
		);

		if (raritySeed < 5) {
			_rarity = 4; // Legendary at 0.5%
		} else if (raritySeed < 60) {
			_rarity = 3; // Epic at 6%
		} else if (raritySeed < 210) {
			_rarity = 2; // Rare at 15%
		} else if (raritySeed < 460) {
			_rarity = 1; // Uncommon at 25%
		} else {
			_rarity = 0; // Common at 54%
		}

		uint16 _minStat = Common._getMinStat(_rarity);
		uint16 _maxStat = Common._getMaxStat(_rarity);

		EquipmentAttributes memory _attributes = EquipmentAttributes(
			Common._getRandomStat(_minStat, _maxStat, seed, 1),
			Common._getRandomStat(_minStat, _maxStat, seed, 2),
			Common._getRandomStat(_minStat, _maxStat, seed, 3),
			Common._getRandomStat(_minStat, _maxStat, seed, 4),
			Common._getRandomStat(_minStat, _maxStat, seed, 5),
			Common._getRandomStat(_minStat, _maxStat, seed, 6)
		);

		equipments.push(
			Equipment(_tokenID, _rarity, _slot, _gender, block.timestamp)
		);
		attributes[_tokenID] = _attributes;

		_safeMint(_minter, _tokenID);

		emit NewEquipment(
			_minter,
			_tokenID,
			_rarity,
			_slot,
			_gender,
			_attributes,
			block.timestamp
		);
	}

	// public functions
	function initialize(string memory _keyHash) public initializer {
		__ERC721_init("Idle Art Online Equipment", "IAOE");
		keyHash = _keyHash;
		__AccessControl_init_unchained();

		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
	}

	function supportsInterface(bytes4 interfaceId)
		public
		view
		virtual
		override(ERC721Upgradeable, AccessControlUpgradeable)
		returns (bool)
	{
		return super.supportsInterface(interfaceId);
	}

	function mintRandomEquipment(
		address _minter,
		uint8 _slot,
		uint8 _gender
	) public restricted {
		uint256 tokenID = equipments.length;
		_mintEquipment(_minter, _slot, _gender, tokenID);
	}
}
