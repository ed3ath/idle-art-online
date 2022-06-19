
const truffle = require('truffle-contract');
const fs = require('fs-extra');
const path = require('path');
const contracts = ["BasicPriceOracle", "CorToken", "Avatars", "Skills", "Events", "Cardinal"];
const file = path.join(__dirname, '../address.json');

async function run() {
    const content = {};
    await Promise.all(contracts.map(async contract => {
        const artifacts = require(`../build/contracts/${contract}.json`);
        const MyContract = truffle(artifacts);
        MyContract.setProvider('http://localhost:8545');
        const myContract = await MyContract.deployed();
        content[contract] = myContract.address;
    }));
    fs.ensureFileSync(file);
    fs.writeFileSync(file, JSON.stringify(content), 'utf-8');
}

run()