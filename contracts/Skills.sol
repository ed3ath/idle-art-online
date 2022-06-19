// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IPriceOracle.sol";
import "./Util.sol";

contract Skills is Initializable, AccessControlUpgradeable {
	using SafeMath for uint256;
	using SafeMath for uint8;
	using SafeERC20Upgradeable for IERC20;

	// struct
	struct Skill {
		uint256 skillId;
		string name;
		uint8 flag; // 0 (non-combat) | 1 (combat)
	}

	// constants
	bytes32 public constant GAME_MASTER = keccak256("GAME_MASTER");

	// variables
	Skill[] private skills;

	string private keyHash;

	// mappings
	mapping(uint256 => mapping(uint16 => uint256)) requirements; // skillId => (attribute index => value)
	mapping(uint256 => Skill[]) avatarSkills; // avatarId => Skills

	// events
	event NewSkill(uint256 skillId, string name, uint8 flag, uint64 timestamp);
	event SkillLearned(uint256 avatarId, uint256 skillId, uint64 timestamp);

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

	// public functions
	function initialize(string memory _keyHash) public initializer {
		__AccessControl_init();

		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

		keyHash = _keyHash;
	}

	function createSkill(string memory name, uint8 flag) external restricted {
		uint256 skillId = skills.length;
		if (skillId == 0) {
			skills.push(Skill(0, "", 0));
			skillId += 1;
		}
		skills.push(Skill(skillId, name, flag));
		emit NewSkill(skillId, name, flag, uint64(block.timestamp));
	}

	function getSkillsLength() public view returns (uint256) {
		return skills.length;
	}

	function getSkill(uint256 skillId) public view returns (Skill memory) {
		return skills[skillId];
	}

	function setSkillRequirement(
		uint256 skillId,
		uint16 attrIndex,
		uint256 value
	) external restricted {
		requirements[skillId][attrIndex] = value;
	}

	function getSkillRequirements(uint256 skillId)
		public
		view
		returns (uint256[] memory)
	{
		uint256[] memory attributes = new uint256[](6);
		for (uint16 i = 0; i < 6; i++) {
			attributes[i] = requirements[skillId][i];
		}
		return attributes;
	}

	function learnSkill(uint256 avatarId, uint256 skillId) external restricted {
		avatarSkills[avatarId].push(skills[skillId]);
		emit SkillLearned(avatarId, skillId, uint64(block.timestamp));
	}

	function getAvatarSkills(uint256 avatarId)
		public
		view
		returns (Skill[] memory)
	{
		return avatarSkills[avatarId];
	}
}
