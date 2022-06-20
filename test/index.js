const CorToken = artifacts.require('CorTest')
const Oracle = artifacts.require('BasicPriceOracle')
const Cardinal = artifacts.require('Cardinal')
const Avatars = artifacts.require('Avatars')
const Skills = artifacts.require('Skills')
const Events = artifacts.require('Events')

contract('Idle Art Online', async (accounts) => {
  let corToken; let oracle; let cardinal; let avatars; let skills; let events; const storeAvatars = []; const storeSkills = []

  const keyHash = '0508bed9fd4f78f10478c995115fdf0b087b42d661e8c6f27710c035187b029b'

  it('Initialize contracts', async () => {
    corToken = await CorToken.new()
    oracle = await Oracle.new()
    cardinal = await Cardinal.new()
    avatars = await Avatars.new()
    skills = await Skills.new()
    events = await Events.new()

    await corToken.transferFrom(corToken.address, accounts[0], web3.utils.toWei('1', 'kether'))
    await oracle.initialize()
    await oracle.setCurrentPrice(10)
    await avatars.initialize(keyHash)
    await skills.initialize(keyHash)
    await events.initialize(keyHash)
    await cardinal.initialize(keyHash, corToken.address, oracle.address, avatars.address, skills.address, events.address)
    await avatars.grantRole(await avatars.GAME_MASTER(), cardinal.address)
    await skills.grantRole(await skills.GAME_MASTER(), cardinal.address)
    await events.grantRole(await events.GAME_MASTER(), cardinal.address)

    avatars.allEvents({}).on('data', async (result) => {
      if (result.event === 'NewAvatar') {
        const { avatarId } = result.returnValues
        const avatar = await avatars.getAvatar(avatarId)
        storeAvatars.push(avatar)
      }
    })

    skills.allEvents({}).on('data', async (result) => {
      if (result.event === 'NewSkill') {
        const { skillId, name, flag, timestamp } = result.returnValues
        storeSkills[name.toLowerCase()] = {
          skillId,
          name,
          flag,
          timestamp
        }
      }
    })

    cardinal.allEvents({}).on('data', async (result) => {
      // console.log(result.returnValues);
    })

    events.allEvents({}).on('data', async (result) => {
      // console.log(result.returnValues);
    })
  })

  it('Account 1: Mint free avatar', async () => {
    await cardinal.mintFreeAvatar({
      from: accounts[1]
    })
  })

  it('Account 2: Mint free avatar', async () => {
    await cardinal.mintFreeAvatar({
      from: accounts[2]
    })
  })

  it('Account 2: Can\'t mint another free avatar - Already claimed free avatar', async () => {
    try {
      await cardinal.mintFreeAvatar({
        from: accounts[2]
      })
    } catch (e) {
      assert.ok(e.message.includes('ACF'))
    }
  })

  it('Cardinal: Create cooking skill', async () => {
    await cardinal.createNewSkill('Cooking', 0, {
      from: accounts[0]
    })
  })

  it('Cardinal: Create healing skill', async () => {
    await cardinal.createNewSkill('Healing', 1, {
      from: accounts[0]
    })
  })

  it('Account 1: Can\'t create mining skill - Not game master', async () => {
    try {
      await cardinal.createNewSkill('Mining', 0, {
        from: accounts[1]
      })
    } catch (e) {
      assert.ok(e.message.includes('NGM'))
    }
  })

  it('Avatar 1: Learn cooking skill using Account 1', async () => {
    await cardinal.learnSkill(storeAvatars[0].avatarId, storeSkills.cooking.skillId, {
      from: accounts[1]
    })
  })

  it('Avatar 1: Can\'t earn cooking skill using Account 2 - Not avatar owner', async () => {
    try {
      await cardinal.learnSkill(storeAvatars[0].avatarId, storeSkills.cooking.skillId, {
        from: accounts[2]
      })
    } catch (e) {
      assert.ok(e.message.includes('NAO'))
    }
  })

  it('Cardinal: Create berserk skill with 50 STR requirements', async () => {
    await cardinal.createNewSkill('Berserk', 1, {
      from: accounts[0]
    })
    await cardinal.setSkillRequirement(3, 5, 50, {
      from: accounts[0]
    })
  })

  it('Cardinal: Give 50 attribute points to Avatar 1', async () => {
    await cardinal.addAttributePoints(storeAvatars[0].avatarId, 50, {
      from: accounts[0]
    })
  })

  it('Account 1: Can\'t give 50 attribute points to Avatar 1 - Not game master', async () => {
    try {
      await cardinal.addAttributePoints(storeAvatars[0].avatarId, 50, {
        from: accounts[1]
      })
    } catch (e) {
      assert.ok(e.message.includes('NGM'))
    }
  })

  it('Account 1: Set 50 STR for Avatar 1', async () => {
    await cardinal.setAttributes(storeAvatars[0].avatarId, 5, 50, {
      from: accounts[1]
    })
  })

  it('Account 1:  Can\'t set another 50 STR for Avatar 1 - Not enough attribute points', async () => {
    try {
      await cardinal.setAttributes(storeAvatars[0].avatarId, 5, 50, {
        from: accounts[1]
      })
    } catch (e) {
      assert.ok(e.message.includes('NAA'))
    }
  })

  it('Avatar 1: Learn berserk skill', async () => {
    await cardinal.learnSkill(storeAvatars[0].avatarId, storeSkills.berserk.skillId, {
      from: accounts[1]
    })
  })

  it('Avatar 2: Can\'t learn berserk skill - Doesn\'t meet the skill requirement', async () => {
    try {
      await cardinal.learnSkill(storeAvatars[1].avatarId, storeSkills.berserk.skillId, {
        from: accounts[2]
      })
    } catch (e) {
      assert.ok(e.message.includes('NMR'))
    }
  })

  it('Cardinal: Set max cor reward for adventure mode to 100', async () => {
    await cardinal.setMaxRewardCor(1, web3.utils.toWei('100', 'ether'), {
      from: accounts[0]
    })
  })

  it('Cardinal: Set max exp reward for adventure mode to 20', async () => {
    await cardinal.setMaxRewardExp(1, 20, {
      from: accounts[0]
    })
  })

  it('Avatar 1: Go on an adventure for 1 hour', async () => {
    await cardinal.doAdventure(storeAvatars[0].avatarId, 1, 1, {
      from: accounts[1]
    })
  })

  it('Should display all random events of Avatar 1 adventure', async () => {
    const advEvents = await cardinal.getAdventureEvents(0)
    await Promise.all(advEvents.map(async event => {
      const { eventType, rewardCor, rewardExp, timestamp } = await events.getEvent(Number(event))
      console.log(`Event type: ${Number(eventType)} | Timestamp: ${Number(timestamp)} | Exp: ${rewardExp} | Cor: ${web3.utils.fromWei(rewardCor, 'ether')}`)
    }))
  })

  it('Avatar 1: Can\'t go on another adventure for 1 hour - Avatar is not available', async () => {
    try {
      await cardinal.doAdventure(storeAvatars[0].avatarId, 1, 1, {
        from: accounts[1]
      })
    } catch (e) {
      assert.ok(e.message.includes('ANA'))
    }
  })
})
