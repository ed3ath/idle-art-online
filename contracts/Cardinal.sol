// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IPriceOracle.sol";
import "./Util.sol";
import "./Avatars.sol";
import "./Skills.sol";

contract Cardinal is Initializable, AccessControlUpgradeable {
	using ABDKMath64x64 for int128;
	using SafeMath for uint256;
	using SafeMath for uint8;
	using SafeERC20 for IERC20;

	// constants
	bytes32 public constant GAME_MASTER = keccak256("GAME_MASTER");

	// variables
	IERC20 public corToken;
	IPriceOracle public priceOracle;

	Avatars public avatars;
	Skills public skills;

	int128 public mintAvatarFee;
	uint8 public maxOwnedAvatar = 8;

	// mappings
	mapping(address => uint256) lastBlockNumberCalled;
	mapping(address => uint8) freeClaims;

	mapping(uint256 => mapping(uint256 => uint256)) parties;
	mapping(uint256 => mapping(uint256 => uint256)) guilds;
	mapping(uint256 => uint64) adventureTimestamp;
	mapping(uint256 => uint256) attributePoints;

	// modifiers
	modifier isAdmin() {
		require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin");
		_;
	}

	modifier restricted() {
		require(hasRole(GAME_MASTER, msg.sender), "Not game master");
		_;
	}

	modifier onlyNonContract() {
		require(tx.origin == msg.sender, "ONC");
		_;
	}

	modifier oncePerBlock(address user) {
		_oncePerBlock(user);
		_;
	}
	
	modifier avatarOwner(uint256 id) {
		require(avatars.ownerOf(id) == msg.sender, "You don't own this avatar");
		_;
	}

	// private functions

	function _oncePerBlock(address user) internal {
		require(lastBlockNumberCalled[user] < block.number, "OCB");
		lastBlockNumberCalled[user] = block.number;
	}

	function _adventure(uint256 avatarId) internal avatarOwner(avatarId) {
		require(avatars.getNftVar(avatarId, 2) == 0, "Avatar is not available");
		require(uint64(block.timestamp) > adventureTimestamp[avatarId], "Avatar is currently tired");		
	}

	// public functions
	function initialize(
		IERC20 _corToken,
		IPriceOracle _priceOracle,
		Avatars _avatars,
		Skills _skills
	) public initializer {
		__AccessControl_init();

		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setupRole(GAME_MASTER, msg.sender);

		corToken = _corToken;
		priceOracle = _priceOracle;

		avatars = _avatars;
		skills = _skills;

		mintAvatarFee = ABDKMath64x64.divu(10, 1);
	}

	function usdToCor(int128 usdAmount) public view returns (uint256) {
		return usdAmount.mulu(priceOracle.currentPrice());
	}

	function mintAvatar() public onlyNonContract oncePerBlock(msg.sender) {
		uint256 corAmount = usdToCor(mintAvatarFee);
		require(corToken.balanceOf(msg.sender) >= corAmount, "Not enough cor");
		require(
			avatars.balanceOf(msg.sender) < maxOwnedAvatar,
			"Maximum number of avatars reached"
		);

		corToken.transferFrom(msg.sender, address(this), corAmount);

		avatars.mintRandomAvatar(msg.sender);
	}

	function mintFreeAvatar() public onlyNonContract oncePerBlock(msg.sender) {
		require(freeClaims[msg.sender] == 0, "Already claimed free avatar");
		require(
			avatars.balanceOf(msg.sender) < maxOwnedAvatar,
			"Maximum number of avatars reached"
		);
		avatars.mintFreeAvatar(msg.sender);
		freeClaims[msg.sender] = 1;
	}

	function doAdventure(uint256 avatarId, uint256 duration) public onlyNonContract {

	}

	function createNewSkill(string memory name, uint8 flag) public restricted {
		skills.createSkill(name, flag);
	}

	function addAttributePoints(uint256 avatarId, uint256 value) public restricted {
		attributePoints[avatarId] += value;
	}

	function setSkillRequirement(uint256 skillId, uint16 attrIndex, uint256 value) public restricted {
		require(skillId > 0 && skillId < skills.getSkillsLength(), "Skill not available");
        skills.setSkillRequirement(skillId, attrIndex, value);
    }

	function setAttributes(uint256 avatarId, uint16 attributeId, uint256 value) public onlyNonContract avatarOwner(avatarId) {
		require(attributePoints[avatarId] >= value, "Not enough attribute points");
		attributePoints[avatarId] -= value;
		avatars.setAttributes(avatarId, attributeId, value);
	}

	// this should be game master only
	function learnSkill(uint256 avatarId, uint256 skillId) public avatarOwner(avatarId) {
		require(skillId > 0 && skillId < skills.getSkillsLength(), "Skill not available");
		uint8 exists = 0;
		Skills.Skill[] memory avatarSkills = skills.getAvatarSkills(avatarId);
		for(uint i; i < avatarSkills.length; i++) {
			if (avatarSkills[i].skillId == skillId) {
				exists = 1;
			}
		}
		require(exists == 0, "You already have this skill");
		uint256[] memory skillRequirement = skills.getSkillRequirements(skillId);
		uint256[] memory attributes = avatars.getAttributes(avatarId);
		uint8 canLearn = 1;
		for(uint i; i < skillRequirement.length; i++ ){
			if (skillRequirement[i] > 0) {
				if (attributes[i] < skillRequirement[i]) {
					canLearn = 0;
				}
			}
		}
		require(canLearn > 0, "You don't meet the requirements");
		skills.learnSkill(avatarId, skillId);
	}
}
