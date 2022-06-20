const Cardinal = artifacts.require("Cardinal");

module.exports = async function (deployer, network, accounts) {
  if (network === "development") {
    const cardinal = await Cardinal.deployed();
    await cardinal.grantRole(await cardinal.GAME_MASTER(), accounts[0]);
    await cardinal.setMaxRewardCor(1, web3.utils.toWei('20', 'ether'));
    await cardinal.setMaxRewardExp(1, 10);
  }
};
