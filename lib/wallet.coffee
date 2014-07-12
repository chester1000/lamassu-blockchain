jsonquest = require 'jsonquest'
async     = require 'async'

insufficientFundsRegex = /(^Insufficient Funds Available)|(^No free outputs to spend)/


class Blockchain
  constructor: (@config) ->
    @host = config.host or 'blockchain.info'
    @port = config.port or 443

  @factory: (config) -> new Blockchain config

  sendBitcoins: (address, satoshis, transactionFee, cb) ->
    config = @config
    path = '/merchant/' + config.guid + '/payment'
    data =
      password: config.password
      to: address
      amount: satoshis
      from: config.fromAddress

    @._request path, data, (err, response, result) ->
      return cb err if err

      if result.error and result.error.match insufficientFundsRegex
        newErr = new Error 'Insufficient funds'
        newErr.name = 'InsufficientFunds'
        return cb newErr

      return cb new Error result.error if result.error

      cb null, result.tx_hash
    return

  balance: (cb) ->
    async.parallel([
        (lcb) => @_checkBalance 0, lcb
        (lcb) => @_checkBalance 1, lcb
      ],
      (err, results) ->
        return cb err if err

        unconfirmedDeposits = results[0].total_received - result[1].total_received
        cb null, results[0].balance - unconfirmedDeposits
    )
    return

  _checkBalance: (conf, cb) ->
    config = @config
    data =
      password: config.password
      address: config.fromAddress

    data.confirmations = conf if conf>0

    path = '/merchant/' + config.guid + '/address_balance'
    @_request path, data, (err, response, result) -> cb err, result
    return

  _request: (path, data, cb) ->
    jsonquest(
      host: @host
      port: @port
      path: path
      body: data
      method: 'POST'
      protocol: 'https'
      requestEncoding: 'queryString'
      ,
      cb
    )
    return

module.exports = Blockchain