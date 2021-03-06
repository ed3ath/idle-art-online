// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IPriceOracle.sol";
import "./Util.sol";
import "./Avatars.sol";
import "./Skills.sol";
import "./Events.sol";

contract Cardinal is Initializable, AccessControlUpgradeable {
	using ABDKMath64x64 for int128;
	using SafeMath for uint256;
	using SafeMath for uint32;
	using SafeMath for uint8;
	using SafeERC20Upgradeable for IERC20;

	// struct
	struct Adventure {
		uint256 advId;
		uint256 avatarId;
		uint64 duration;
		uint64 timestamp;
	}

	// constants
	bytes32 public constant GAME_MASTER = keccak256("GAME_MASTER");

	uint256 public constant STAKING_COOLDOWN = 1; // 1 (hour) | 2 (day) | 3 (week) | 4 (month)

	uint256 public constant VAR_REWARD_COR = 10; // 1 (adventure) | 2 (solo dungeon) | 3 (party dungeon) | 4 (boss room)
	uint256 public constant VAR_REWARD_EXP = 11; // 1 (adventure) | 2 (solo dungeon) | 3 (party dungeon) | 4 (boss room)

	uint8 public constant MODE_ADVENTURE = 1;
	uint8 public constant MODE_SOLO = 2;
	uint8 public constant MODE_PARTY = 3;
	uint8 public constant MODE_GUILD = 4;

	// variables
	Adventure[] public adventures;
	IERC20 public corToken;
	IPriceOracle public priceOracle;

	Avatars public avatars;
	Skills public skills;
	Events public events;

	string private keyHash;

	int128 public mintAvatarFee;
	uint8 public maxOwnedAvatar;

	// mappings
	mapping(address => uint256) lastBlockNumberCalled;
	mapping(address => uint256) freeClaims;

	mapping(uint256 => mapping(uint256 => uint256)) gameVars;
	mapping(uint256 => mapping(uint256 => uint256)) parties;
	mapping(uint256 => mapping(uint256 => uint256)) guilds;
	mapping(uint256 => uint64) avatarCooldowns;
	mapping(uint256 => uint256) attributePoints;
	mapping(uint256 => uint256[]) adventureEvents;
	mapping(uint256 => uint256) avatarAdvId;

	// events
	event AdventureStarted(
		uint256 advId,
		uint256 avatarId,
		uint64 duration,
		uint64 timestamp
	);
	event AdventureEnded(
		uint256 advId,
		uint256 avatarId,
		uint64 timestamp
	);

	// modifiers
	modifier isAdmin() {
		require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "NOA"); //Not admin
		_;
	}

	modifier restricted() {
		require(hasRole(GAME_MASTER, msg.sender), "NGM"); //Not game master
		_;
	}

	modifier onlyNonContract() {
		require(tx.origin == msg.sender, "ONC"); //Only non contract
		_;
	}

	modifier oncePerBlock(address user) {
		_oncePerBlock(user);
		_;
	}

	modifier avatarOwner(uint256 id) {
		require(avatars.ownerOf(id) == msg.sender, "NAO"); //Not avatar owner
		_;
	}

	modifier skillAvailable(uint256 skillId) {
		require(
			skillId > 0 && skillId < skills.getSkillsLength(),
			"SNA" // Skill not available
		);
		_;
	}

	modifier validAttribute(uint256 attributeId) {
		require(attributeId >= 0 && attributeId < 6, "UNA"); //Unknown attribute
		_;
	}

	// private functions
	function _oncePerBlock(address user) internal {
		require(lastBlockNumberCalled[user] < block.number, "OCB");
		lastBlockNumberCalled[user] = block.number;
	}

	function _durationToSeconds(uint8 durationType, uint32 duration)
		internal
		pure
		returns (uint64)
	{
		require(durationType > 0 && durationType < 5, "IDT"); //Invalid duration type
		uint64 mult = 0;
		if (durationType == 1) mult = 3600;
		else if (durationType == 2) mult = 86400;
		else if (durationType == 3) mult = 604800;
		else mult = 2592000;
		return uint64(duration * mult);
	}

	// public functions
	function initialize(
		string memory _keyHash,
		IERC20 _corToken,
		IPriceOracle _priceOracle,
		Avatars _avatars,
		Skills _skills,
		Events _events
	) public initializer {
		__AccessControl_init();

		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setupRole(GAME_MASTER, msg.sender);

		keyHash = _keyHash;

		corToken = _corToken;
		priceOracle = _priceOracle;

		avatars = _avatars;
		skills = _skills;
		events = _events;

		maxOwnedAvatar = 8;

		mintAvatarFee = ABDKMath64x64.divu(10, 1);
	}

	function usdToCor(int128 usdAmount) public view returns (uint256) {
		return usdAmount.mulu(priceOracle.currentPrice());
	}

	function mintAvatar() public onlyNonContract oncePerBlock(msg.sender) {
		uint256 corAmount = usdToCor(mintAvatarFee);
		require(corToken.balanceOf(msg.sender) >= corAmount, "NEC"); //Not enough cor
		require(
			avatars.balanceOf(msg.sender) < maxOwnedAvatar,
			"MNA" //Maximum number of avatars reached
		);

		corToken.transferFrom(msg.sender, address(this), corAmount);

		avatars.mintRandomAvatar(msg.sender);
	}

	function getStakingCooldown(uint8 durationType)
		public
		view
		returns (uint64)
	{
		return uint64(gameVars[STAKING_COOLDOWN][durationType]);
	}

	function mintFreeAvatar() public onlyNonContract oncePerBlock(msg.sender) {
		require(freeClaims[msg.sender] == 0, "ACF"); //Already claimed free avatar
		require(
			avatars.balanceOf(msg.sender) < maxOwnedAvatar,
			"MNA" //Maximum number of avatars reached
		);
		uint256 avatarId = avatars.mintFreeAvatar(msg.sender);
		freeClaims[msg.sender] = avatarId;
	}

	function getFreeMintAvatarId(address minter) public view returns (uint256) {
		return freeClaims[minter];
	}

	function doAdventure(
		uint256 avatarId,
		uint8 durationType,
		uint32 duration
	) public onlyNonContract avatarOwner(avatarId) returns (uint256) {
		require(avatars.getNftVar(avatarId, 2) == 0, "ANA"); //Avatar is not available
		require(
			uint64(block.timestamp) > avatarCooldowns[avatarId],
			"ACT" //Avatar is currently tired
		);
		uint64 advDuration = _durationToSeconds(durationType, duration);
		require(advDuration <= 86400, "DL1"); //Duration should not be longer than 1 day
		uint256 advId = adventures.length;
		if (advId == 0) {
			adventures.push(Adventure(0, 0, 0, uint64(0)));
		}
		avatars.setNftVar(avatarId, avatars.VAR_STATUS(), 1);
		adventures.push(
			Adventure(advId, avatarId, advDuration, uint64(block.timestamp))
		);
		avatarCooldowns[avatarId] = uint64(block.timestamp + advDuration);
		emit AdventureStarted(
			advId,
			avatarId,
			advDuration,
			uint64(block.timestamp)
		);
		avatarAdvId[avatarId] = advId;
		return advId;
	}

	function getAvatarAdvId(uint256 avatarId) public view returns (uint256) {
		return avatarAdvId[avatarId];
	}

	function endAdventure(uint256 avatarId)
		public
		onlyNonContract
		avatarOwner(avatarId)
	{
		uint256 advId = avatarAdvId[avatarId];
		avatarAdvId[avatarId] = 0;
		avatars.setNftVar(avatarId, avatars.VAR_STATUS(), 0);
		avatarCooldowns[avatarId] = 0;
		emit AdventureEnded(advId, avatarId, uint64(block.timestamp));
	}

	function createAdventureRandomEvent(uint256 advId, uint8 eventType, uint256 rewardCor, uint256 rewardExp) public restricted {
		require(advId > 0 && advId < adventures.length, 'IID'); // Invalid adventure ID;
		require(rewardCor <= gameVars[VAR_REWARD_COR][MODE_ADVENTURE], 'RCE'); // Reward cor exceeded the max limit
		require(rewardExp <= gameVars[VAR_REWARD_EXP][MODE_ADVENTURE], 'REE'); // Reward exp exceeded the max limit

		uint256 eventId = events.createEvent(
			MODE_ADVENTURE,
			eventType,
			rewardCor,
			rewardExp,
			uint64(block.timestamp)
		);
		adventureEvents[advId].push(eventId);
	}

	function getAdventureEvents(uint256 advId)
		public
		view
		returns (uint256[] memory)
	{
		return adventureEvents[advId];
	}

	function createNewSkill(string memory name, uint8 flag) public restricted {
		skills.createSkill(name, flag);
	}

	function addAttributePoints(uint256 avatarId, uint256 value)
		public
		restricted
	{
		attributePoints[avatarId] += value;
	}

	function setSkillRequirement(
		uint256 skillId,
		uint16 attrIndex,
		uint256 value
	) public restricted skillAvailable(skillId) {
		skills.setSkillRequirement(skillId, attrIndex, value);
	}

	function setAttributes(
		uint256 avatarId,
		uint8 attributeId,
		uint16 value
	) public onlyNonContract avatarOwner(avatarId) validAttribute(attributeId) {
		require(
			attributePoints[avatarId] >= value,
			"NAA" //Not enough attribute points
		);
		avatars.setAttributes(avatarId, attributeId, value);
		attributePoints[avatarId] -= value;
	}

	function learnSkill(uint256 avatarId, uint256 skillId)
		public
		avatarOwner(avatarId)
		skillAvailable(skillId)
	{
		uint8 exists = 0;
		Skills.Skill[] memory avatarSkills = skills.getAvatarSkills(avatarId);
		for (uint256 i; i < avatarSkills.length; i++) {
			if (avatarSkills[i].skillId == skillId) {
				exists = 1;
			}
		}
		require(exists == 0, "AHS"); //You already have this skill
		uint256[] memory skillRequirement = skills.getSkillRequirements(
			skillId
		);
		uint16[] memory attributes = avatars.getAttributes(avatarId);
		uint8 canLearn = 1;
		for (uint256 i; i < skillRequirement.length; i++) {
			if (skillRequirement[i] > 0) {
				if (attributes[i] < skillRequirement[i]) {
					canLearn = 0;
				}
			}
		}
		require(canLearn > 0, "NMR"); //You don't meet the requirements
		skills.learnSkill(avatarId, skillId);
	}

	function setMaxRewardCor(uint8 mode, uint256 amount) public restricted {
		gameVars[VAR_REWARD_COR][mode] = amount;
	}

	function getMaxRewardCor(uint8 mode) public view returns (uint256) {
		return gameVars[VAR_REWARD_COR][mode];
	}

	function setMaxRewardExp(uint8 mode, uint256 amount) public restricted {
		gameVars[VAR_REWARD_EXP][mode] = amount;
	}

	function getMaxRewardExp(uint8 mode) public view returns (uint256) {
		return gameVars[VAR_REWARD_EXP][mode];
	}
}
