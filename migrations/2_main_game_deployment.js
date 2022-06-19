const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const BasicPriceOracle = artifacts.require("BasicPriceOracle");
const CorToken = artifacts.require("CorToken");
const Avatars = artifacts.require("Avatars");
const Skills = artifacts.require("Skills");
const Events = artifacts.require("Events");

const Cardinal = artifacts.require("Cardinal");

const keyHash = "0508bed9fd4f78f10478c995115fdf0b087b42d661e8c6f27710c035187b029b";

module.exports = async function (deployer, network, accounts) {
  if (network === 'development') {
    const oracle = await deployProxy(BasicPriceOracle, [], { deployer });    
    const corToken = await deployer.deploy(CorToken);
    const avatars = await deployProxy(Avatars, [keyHash], { deployer });
    const skills = await deployProxy(Skills, [keyHash], { deployer });
    const events = await deployProxy(Events, [keyHash], { deployer });
    const cardinal = await deployProxy(Cardinal, [keyHash, corToken.address, oracle.address, avatars.address, skills.address, events.address], { deployer });

    await corToken.transferFrom(corToken.address, accounts[1], web3.utils.toWei("1", "kether"));
    await oracle.setCurrentPrice(10);
    await avatars.grantRole(await avatars.GAME_MASTER(), cardinal.address);
    await skills.grantRole(await skills.GAME_MASTER(), cardinal.address);
    await events.grantRole(await events.GAME_MASTER(), cardinal.address);

  }
};
