// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./Util.sol";
import "./Common.sol";

contract Avatars is Initializable, ERC721Upgradeable, AccessControlUpgradeable {
	using SafeMath for uint256;
	using SafeMath for uint16;
	using SafeMath for uint8;

	// struct
	struct Avatar {
		uint256 avatarId;
		uint8 rarity;
		uint8 gender;
		uint16 level;
		uint256 exp;
		AvatarGenes genes;
		uint256 timestamp;
		address minter;
	}

	struct AvatarGenes {
		uint8 bodyShape;
		uint8 faceShape;
		uint8 hairType;
		uint8 hairColor;
		uint8 eyeColor;
		uint8 skinColor;
	}
	
	// constants
	bytes32 public constant GAME_MASTER = keccak256("GAME_MASTER");
	uint256 public constant VAR_FREE = 1;
	uint256 public constant VAR_STATUS = 2; // 1 (adventure) | 2 (solo dungeon) | 3 (party dungeon) | 4 (boss room)
	uint256 public constant VAR_PARTY = 3;
	uint256 public constant VAR_GUILD = 4;

	// variables
	Avatar[] private avatars;

	uint16 public maxLevel;
	uint16 public maxEquipmentSlot;
	string private keyHash;

	// mappings
	mapping(uint256 => mapping(uint256 => uint256)) nftVars;
	/*
		attribute index
		0 = charisma
		1 = constitution
		2 = dexterity
		3 = intelligence
		4 = perception
		5 = strength
	*/
	mapping(uint256 => mapping(uint16 => uint256)) attributes; // avatarID => [attribute => value]
	/*
		slot index
		0 = weapon
		1 = shield
		2 = upper body
		3 = lower body
		4 = hands
		5 = feet
		6 = cape
		7 = ring
		8 = necklace
		9 = earring
	*/
	mapping(uint256 => mapping(uint256 => uint256)) equipments; // avatarID => [slot => itemId]

	// events
	event NewAvatar(
		address indexed minter,
		uint256 avatarId,
		uint8 gender,
		uint8 rarity,
		uint256 timestamp
	);
	event LevelUp(address indexed owner, uint256 avatarId, uint16 level);

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
	function _mintAvatar(
		address minter,
		uint256 avatarId,
		uint8 rarity,
		uint8 gender,
		AvatarGenes memory genes,
		uint8 _isFree
	) internal {
		if (avatarId == 0) {
			avatars.push(
				Avatar(
					0,
					0,
					0,
					0,
					0,
					AvatarGenes(0, 0, 0, 0, 0, 0),
					0,
					address(0)
				)
			);
			avatarId += 1;
		}
		uint16 _minStat = Common._getMinStat(rarity);
		uint16 _maxStat = Common._getMaxStat(rarity);

		uint256 seed = RandomUtil.getRandomSeed(keyHash, minter, avatarId);

		for(uint16 i = 0; i < 6; i++){
			attributes[avatarId][i] = Common._getRandomStat(_minStat, _maxStat, seed, i);
		}

		for(uint16 i = 0; i < maxEquipmentSlot; i++){
			equipments[avatarId][i] = 0;
		}

		avatars.push(
			Avatar(
				avatarId,
				rarity,
				gender,
				0,
				0,
				genes,
				block.timestamp,
				minter
			)
		);

		nftVars[avatarId][VAR_FREE] = _isFree;

		_safeMint(minter, avatarId);

		emit NewAvatar(
			minter,
			avatarId,
			gender,
			rarity,
			block.timestamp
		);
	}

	function _gainExp(uint256 avatarId, uint256 exp) internal {
		Avatar storage avatar = avatars[avatarId];
		if (avatar.level < maxLevel) {
			uint256 newExp = avatar.exp.add(exp);
			uint256 requiredToLevel = _getExpRequired(avatar.level);
			while (newExp >= requiredToLevel) {
				newExp = newExp - requiredToLevel;
				avatar.level += 1;
				emit LevelUp(ownerOf(avatarId), avatarId, avatar.level);
				if (avatar.level < maxLevel)
					requiredToLevel = _getExpRequired(avatar.level);
				else newExp = 0;
			}
			avatar.exp = uint256(newExp);
		}
	}

	function _getExpRequired(uint16 level) internal pure returns (uint256) {
		return uint256(level.mul(50).mul(level.sub(1)));
	}

	// public function
	function initialize(string memory _keyHash) public initializer {
		__ERC721_init("Idle Art Online Avatar", "IAOA");
		keyHash = _keyHash;
		maxLevel = 1000;
		maxEquipmentSlot = 9;

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

	function mintRandomAvatar(address minter) external restricted {
		uint256 avatarId = avatars.length;
		uint8 rarity;
		uint256 seed = RandomUtil.getRandomSeed(keyHash, minter, avatarId);
		uint8 gender = Common._getRandomGender(seed, 0);
		uint256 raritySeed = RandomUtil.randomSeededMinMax(
			1,
			1000,
			uint8(seed % block.timestamp)
		);

		if (raritySeed < 5) {
			rarity = 4; // Legendary at 0.5%
		} else if (raritySeed < 60) {
			rarity = 3; // Epic at 6%
		} else if (raritySeed < 210) {
			rarity = 2; // Rare at 15%
		} else if (raritySeed < 460) {
			rarity = 1; // Uncommon at 25%
		} else {
			rarity = 0; // Common at 54%
		}

		AvatarGenes memory genes = AvatarGenes(
			Common._getRandomGene(seed, 1, 5),
			Common._getRandomGene(seed, 2, 5),
			Common._getRandomGene(seed, 3, 5),
			Common._getRandomGene(seed, 4, 5),
			Common._getRandomGene(seed, 5, 5),
			Common._getRandomGene(seed, 6, 5)
		);
		_mintAvatar(
			minter,
			avatarId,
			rarity,
			gender,
			genes,
			0
		);
	}

	function mintFreeAvatar(address minter) external restricted {
		uint256 avatarId = avatars.length;
		uint8 rarity = 0; // free mints are always common
		uint256 seed = RandomUtil.getRandomSeed(keyHash, minter, avatarId);
		uint8 gender = Common._getRandomGender(seed, 0);

		AvatarGenes memory genes = AvatarGenes(
			Common._getRandomGene(seed, 1, 5),
			Common._getRandomGene(seed, 2, 5),
			Common._getRandomGene(seed, 3, 5),
			Common._getRandomGene(seed, 4, 5),
			Common._getRandomGene(seed, 5, 5),
			Common._getRandomGene(seed, 6, 5)
		);
		_mintAvatar(
			minter,
			avatarId,
			rarity,
			gender,
			genes,
			1
		);
	}

	function getAvatar(uint256 avatarId) public view returns (Avatar memory, uint256[] memory) {
		return (avatars[avatarId], getAttributes(avatarId));
	}

	function getAttributes(uint256 avatarId) public view returns (uint256[] memory) {
		uint256[] memory attribute = new uint256[](6);
		for(uint16 i = 0; i < 6; i++) {
			attribute[i] = attributes[avatarId][i];
		}
		return attribute;
	}

	function gainExp(uint256 avatarId, uint256 exp) external restricted {
		require(exp > 0, "No exp to gain.");
		_gainExp(avatarId, exp);
	}

	function setMaxLevel(uint16 max) external restricted {
		maxLevel = max;
	}

	function setMaxEquipmentSlot(uint16 max) external restricted {
		maxEquipmentSlot = max;
	}

	function getNftVar(uint256 avatarId, uint256 nftVar) public view returns(uint256) {
        return nftVars[avatarId][nftVar];
    }

    function setNftVar(uint256 avatarId, uint256 nftVar, uint256 value) public restricted {
        nftVars[avatarId][nftVar] = value;
    }

	function setEquipment(uint256 avatarId, uint8 slot, uint256 itemId) public restricted {
		equipments[avatarId][slot] = itemId;
	}

	function getEquipment(uint256 avatarId, uint8 slot) public view returns(uint256) {
		return equipments[avatarId][slot];
	}

	function getEquipments(uint256 avatarId) public view returns(uint256[] memory) {
		uint256[] memory items = new uint256[](maxEquipmentSlot);
		for(uint i = 0; i < maxEquipmentSlot; i++) {
			items[i] = equipments[avatarId][i];
		}
		return items;
	}
}
