module.exports = {
  port: process.env.PORT || 3000,
  mongo_uri: process.env.MONGODB_URI || 'mongodb://localhost:27017/ioa',
  rpc_uri: {
    http: 'http://localhost:8545/',
    ws: 'ws://localhost:8545/'
  }

}
