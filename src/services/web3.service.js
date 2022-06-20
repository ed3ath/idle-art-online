const Web3 = require('web3')

const config = require('../config')
const address = require('../../address.json')

const avatarsAbi = require('../../build/contracts/Avatars.json')
const skillsAbi = require('../../build/contracts/Skills.json')
const eventsAbi = require('../../build/contracts/Events.json')
const cardinalAbi = require('../../build/contracts/Cardinal.json')

class Web3Service {
  constructor () {
    this.web3 = new Web3(config.rpc_uri.http)
    this.wssWeb3 = new Web3(config.rpc_uri.ws)
    this.contracts = {
      avatars: new this.web3.eth.Contract(avatarsAbi.abi, address.Avatars),
      skills: new this.web3.eth.Contract(skillsAbi.abi, address.Avatars),
      events: new this.web3.eth.Contract(eventsAbi.abi, address.Events),
      cardinal: new this.web3.eth.Contract(cardinalAbi.abi, address.Cardinal)
    }
    this.wssContracts = {
      avatars: new this.wssWeb3.eth.Contract(avatarsAbi.abi, address.Avatars),
      skills: new this.wssWeb3.eth.Contract(skillsAbi.abi, address.Avatars),
      events: new this.wssWeb3.eth.Contract(eventsAbi.abi, address.Events),
      cardinal: new this.wssWeb3.eth.Contract(cardinalAbi.abi, address.Cardinal)
    }
  }
}

module.exports = Web3Service
