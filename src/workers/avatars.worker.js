module.exports = (web3Service) => {
  const { wssContracts } = web3Service

  wssContracts.avatars.events
    .allEvents()
    .on('connected', () => {
      console.log('subscribed to avatars events')
    })
    .on('data', (data) => {
      console.log(data)
    })
  wssContracts.cardinal.events
    .allEvents()
    .on('connected', () => {
      console.log('subscribed to cardinal events')
    })
    .on('data', (data) => {
      console.log(data)
    })
}
