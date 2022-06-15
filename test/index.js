const CorToken = artifacts.require("CorTest");
const Oracle = artifacts.require("BasicPriceOracle");
const Cardinal = artifacts.require("Cardinal");
const Avatars = artifacts.require("Avatars");
const Skills = artifacts.require("Skills");
const Events = artifacts.require("Events");

contract("Idle Art Online", async (accounts) => {
  let corToken, oracle, cardinal, avatars, skills, events, storeAvatars = [], storeSkills = [];

  const keyHash = "0508bed9fd4f78f10478c995115fdf0b087b42d661e8c6f27710c035187b029b";

  it("Should initialize contracts", async () => {
    corToken = await CorToken.new();
    oracle = await Oracle.new();
    cardinal = await Cardinal.new();
    avatars = await Avatars.new();
    skills = await Skills.new();
    events = await Events.new();

    await corToken.transferFrom(corToken.address, accounts[0], web3.utils.toWei("1", "kether"));
    await oracle.initialize();
    await oracle.setCurrentPrice(10);
    await avatars.initialize(keyHash);
    await skills.initialize(keyHash);
    await events.initialize(keyHash);
    await cardinal.initialize(corToken.address, oracle.address, avatars.address, skills.address, events.address);
    await avatars.grantRole(await avatars.GAME_MASTER(), cardinal.address);
    await skills.grantRole(await skills.GAME_MASTER(), cardinal.address);
    await events.grantRole(await events.GAME_MASTER(), cardinal.address);
 
    avatars.allEvents({}).on('data', async (result) => {
      if (result.event === 'NewAvatar') {
        const { minter, avatarId, gender, rarity } = result.returnValues;
        const avatar = await avatars.getAvatar(avatarId);
        storeAvatars.push(avatar);
      }
    })

    skills.allEvents({}).on('data', async (result) => {
      if (result.event === 'NewSkill') {
        const { skillId, name, flag, timestamp } = result.returnValues;
        storeSkills[name.toLowerCase()] = {
          skillId,
          name,
          flag,
          timestamp
        }
      }
    })
   });

  it(`Account 1 should mint free avatar`, async () => {
    await cardinal.mintFreeAvatar({
      from: accounts[1],
    });
  }); 
  
  it(`Account 2 should mint free avatar`, async () => {
    await cardinal.mintFreeAvatar({
      from: accounts[2],
    });
  });
  
  it(`Account 2 should fail to mint another free avatar`, async () => {
    try {
      await cardinal.mintFreeAvatar({
        from: accounts[2],
      });
    }catch(e) {
      assert.ok(e.message.includes("Already claimed free avatar"));
    }
  });

  it(`Account 0 should create cooking skill`, async () => {
    await cardinal.createNewSkill('Cooking', 0, {
      from: accounts[0],
    });
  });

  it(`Account 0 should create a healing skill`, async () => {
    await cardinal.createNewSkill('Healing', 1, {
      from: accounts[0],
    });
  });

  it(`Account 1 should fail to create mining skill`, async () => {
    try {
      await cardinal.createNewSkill('Mining', 0, {
        from: accounts[1],
      });
    }catch(e) {
      assert.ok(e.message.includes("Not game master"));
    }
  });

  it(`Avatar 1 should learn cooking skill using Account 1`, async () => {
    await cardinal.learnSkill(storeAvatars[0].avatarId, storeSkills['cooking'].skillId, {
      from: accounts[1]
    });
  });

  it(`Avatar 1 should fail to learn cooking skill using Account 2`, async () => {
    try {
      await cardinal.learnSkill(storeAvatars[0].avatarId, storeSkills['cooking'].skillId, {
        from: accounts[2]
      });
    }catch(e) {
      assert.ok(e.message.includes("You don't own this avatar"));
    }
  });

  it(`Account 0 should create a combat skill with required STR`, async () => {
    await cardinal.createNewSkill('Berserk', 1, {
      from: accounts[0]
    });
    await cardinal.setSkillRequirement(3, 5, 50, {
      from: accounts[0]
    });
  });

  it(`Account 0 should give Avatar 1 50 attribute points`, async () => {
    await cardinal.addAttributePoints(storeAvatars[0].avatarId, 50, {
      from: accounts[0]
    });
  });

  it(`Account 1 should fail to give Avatar 1 50 attribute points`, async () => {
    try {
      await cardinal.addAttributePoints(storeAvatars[0].avatarId, 50, {
        from: accounts[1]
      });
    }catch(e) {
      assert.ok(e.message.includes("Not game master"));
    }
  });

  it(`Account 1 should set 50 STR for Avatar 1`, async () => {
    await cardinal.setAttributes(storeAvatars[0].avatarId, 5, 50, {
      from: accounts[1]
    });
  });

  it(`Account 1 should fail to set another 50 STR for Avatar 1`, async () => {
    try {
      await cardinal.setAttributes(storeAvatars[0].avatarId, 5, 50, {
        from: accounts[1]
      });
    }catch(e) {
      assert.ok(e.message.includes("Not enough attribute points"));
    }
  });

  it(`Avatar 1 should learn berskerk skill`, async () => {
    await cardinal.learnSkill(storeAvatars[0].avatarId, storeSkills['berserk'].skillId, {
      from: accounts[1]
    });
  });

  it(`Avatar 2 should fail to learn berskerk skill`, async () => {
    try {
      await cardinal.learnSkill(storeAvatars[1].avatarId, storeSkills['berserk'].skillId, {
        from: accounts[2]
      });
    }catch(e) {
      assert.ok(e.message.includes("You don't meet the requirements"));
    }
  });

  it('Avatar 1 should do an adventure for 1 hour using Account 1', async () => {
    await cardinal.doAdventure(storeAvatars[0].avatarId, 1, 1, {
      from: accounts[1]
    });
  });

  it('Avatar 1 should fail to do another adventure for 1 hour using Account 1', async () => {
    try {
      await cardinal.doAdventure(storeAvatars[0].avatarId, 1, 1, {
        from: accounts[1]
      });
    }catch(e) {
      assert.ok(e.message.includes("Avatar is not available"));
    }
  });

  it('Account 0 should create event for adventure 1', async () => {
    await cardinal.createAdventureEvent(0, 1, 1000, 2000, {
      from: accounts[0]
    });
  });

  it('Account 1 should fail to create event for adventure 0', async () => {
    try {
      await cardinal.createAdventureEvent(0, 1, 1000, 2000, {
        from: accounts[1]
      });
    }catch(e) {
      assert.ok(e.message.includes("Not game master"));
    }
  });

  it('Cor reward should be equal to 1000 and exp reward should be equal to 2000 from 1st event of adventure 0', async () => {
    const advEvents = await cardinal.getAdventureEvents(0);
    const { rewardCor, rewardExp } = await events.getEvent(Number(advEvents[0]));
    assert.ok(Number(rewardCor) === 1000 && Number(rewardExp) === 2000);
  });
  
});

function rarityToName(rarity) {
  if (rarity === 4) return 'Legendary';
  else if (rarity === 3) return 'Epic';
  else if (rarity === 2) return 'Rare';
  else if (rarity === 1) return 'Uncommon';
  else return 'Common';
}

function attrToName(attr) {
  if (attr === 0) return 'CHA';
  else if (attr === 1) return 'CON';
  else if (attr === 2) return 'DEX';
  else if (attr === 3) return 'INT';
  else if (attr === 4) return 'PER';
  else if (attr === 5) return 'STR';
  else return '??'
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}