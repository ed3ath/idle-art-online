// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IPriceOracle.sol";
import "./Util.sol";

contract Events is Initializable, AccessControlUpgradeable {
	using SafeMath for uint256;
	using SafeMath for uint8;
	using SafeERC20Upgradeable for IERC20;

	// struct
	struct Event {
		uint256 eventId;
		uint8 eventMode;
		uint8 eventType;
		uint256 rewardCor;
		uint256 rewardExp;
		uint64 timestamp;
	}

	struct RewardItem {
		uint256 itemId;
		uint256 quantity;
	}

	// constants
	bytes32 public constant GAME_MASTER = keccak256("GAME_MASTER");

	// variables
	Event[] private events;

	string private keyHash;

	// mappings
	mapping(uint256 => uint8) eventStatus; // eventId => status: 0 (active) | 1 (completed) | 2 (failed)
	mapping(uint256 => RewardItem[]) eventRewardItems; // eventId => (index => RewardItem)

	// events
	event NewEvent(
		uint256 eventId,
		uint8 eventMode,
		uint8 eventType,
		uint256 rewardCor,
		uint256 rewardExp,
		uint64 timestamp
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

	// public functions
	function initialize(string memory _keyHash) public initializer {
		__AccessControl_init();

		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

		keyHash = _keyHash;
	}

	function createEvent(
		uint8 eventMode,
		uint8 eventType,
		uint256 rewardCor,
		uint256 rewardExp,
		uint64 timestamp
	) external restricted returns (uint256) {
		uint256 eventId = events.length;
		events.push(
			Event(
				eventId,
				eventMode,
				eventType,
				rewardCor,
				rewardExp,
				timestamp
			)
		);
		emit NewEvent(
			eventId,
			eventMode,
			eventType,
			rewardCor,
			rewardExp,
			timestamp
		);
		return eventId;
	}

	function getEvent(uint256 eventId) public view returns (Event memory) {
		return events[eventId];
	}

	function addRewardItem(
		uint256 eventId,
		uint256 itemId,
		uint256 quantity
	) external restricted {
		eventRewardItems[eventId].push(RewardItem(itemId, quantity));
	}

	function getRewardItems(uint256 eventId)
		public
		view
		returns (RewardItem[] memory)
	{
		return eventRewardItems[eventId];
	}
}
