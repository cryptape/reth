# -*- encoding : ascii-8bit -*-

require 'devp2p'
require 'ethereum'

module Reth

  CLIENT_NAME = 'reth'
  CLIENT_VERSION = "#{VERSION}/#{RUBY_PLATFORM}/#{RUBY_ENGINE}-#{RUBY_VERSION}"
  CLIENT_VERSION_STRING = "#{CLIENT_NAME}-v#{CLIENT_VERSION}"

  Env         = Ethereum::Env
  DB          = Ethereum::DB
  BlockHeader = Ethereum::BlockHeader
  Block       = Ethereum::Block
  Transaction = Ethereum::Transaction
  Chain       = Ethereum::Chain

  Logger = BlockLogger

end

require 'reth/utils'
require 'reth/config'
require 'reth/profile'

require 'reth/keystore'
require 'reth/account'

require 'reth/duplicates_filter'
require 'reth/sync_task'
require 'reth/synchronizer'

require 'reth/transient_block'
require 'reth/eth_protocol'

require 'reth/account_service'
require 'reth/db_service'
require 'reth/leveldb_service'
require 'reth/chain_service'

require 'reth/app'

