module.exports = (server, web3Service) => {
  server.get('/users', (req, res, next) => {
    res.send({ msg: 'test' })
    next()
  })
}
