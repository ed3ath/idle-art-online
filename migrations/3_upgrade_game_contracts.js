const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');

const BasicPriceOracle = artifacts.require("BasicPriceOracle");
const CorToken = artifacts.require("CorToken");
const Avatars = artifacts.require("Avatars");
const Skills = artifacts.require("Skills");
const Events = artifacts.require("Events");

const Cardinal = artifacts.require("Cardinal");

const keyHash = "0508bed9fd4f78f10478c995115fdf0b087b42d661e8c6f27710c035187b029b";

async function upgrade(contract, deployer) {
  const deployedContract = await contract.deployed();
  return await upgradeProxy(deployedContract.address, contract, { deployer });
}

module.exports = async function (deployer, network) {
  if (network === 'development') {
    await upgrade(Avatars, deployer);
    await upgrade(Skills, deployer);
    await upgrade(Events, deployer);
    await upgrade(Cardinal, deployer);
  }
};
