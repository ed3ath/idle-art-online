const restify = require('restify')
const mongoose = require('mongoose')
const cluster = require('cluster')

const config = require('./config')
const Web3Service = require('./services/web3.service')

const web3Service = new Web3Service()

if (cluster.isPrimary) {
  console.log(`Primary ${process.pid} is running`)

  const server = restify.createServer()

  server.use(restify.plugins.bodyParser())

  server.listen(config.port, () => {
    mongoose.connect(config.mongo_uri, { useNewUrlParser: true })
  })

  const db = mongoose.connection

  db.on('error', (err) => console.log(err))

  db.once('open', () => {
    require('./routes/users')(server, web3Service)
    console.log(`Server running on port ${config.port}`)
  })

  cluster.fork()
  cluster.on('exit', (worker, code, signal) => {
    console.log(`Service worker ${worker.process.pid} died`)
  })
} else {
  require('./workers/avatars.worker')(web3Service)
  console.log(`Service worker ${process.pid} started`)
}
