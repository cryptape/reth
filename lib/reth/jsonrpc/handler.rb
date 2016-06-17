module Reth
module JSONRPC

  module Handler
    include Helper

    def handle_web3_clientVersion
      CLIENT_VERSION_STRING
    end

    def handle_web3_sha3(hex)
      bytes = hex_to_bytes hex
      bytes_to_hex Utils.keccak256(bytes)
    end

    def handle_net_version
      discovery.protocol.class::VERSION
    end

    def handle_net_listening
      peermanager.num_peers < peermanager.config.p2p.min_peers
    end

    def handle_net_peerCount
      int_to_hex peermanager.num_peers
    end

    def handle_eth_protocolVersion
      ETHProtocol.version
    end

    def handle_eth_syncing
      return false unless chain.syncing?

      synctask = chain.synchronizer.synctask
      {
        startingBlock: int_to_hex(synctask.start_block_number),
        currentBlock: int_to_hex(chain.chain.head.number),
        highestBlock: int_to_hex(synctask.end_block_number)
      }
    end

    # TODO: real accounts
    def handle_eth_coinbase
      bytes_to_hex Ethereum::PrivateKey.new(Account.test_accounts.values.first).to_address
    end

    def handle_eth_mining
      false
    end

    def handle_eth_hashrate
      int_to_hex 0
    end

    def handle_eth_gasPrice
      int_to_hex 1
    end

    def handle_eth_accounts
      Account.test_accounts.keys
    end

    def handle_eth_blockNumber
      int_to_hex chain.chain.head.number
    end

    def handle_eth_getBalance(address, block_tag=@default_block)
      block = get_block decode_block_tag(block_tag)
      int_to_hex block.get_balance(hex_to_bytes(address))
    end

    def handle_eth_getStorageAt(address, key, block_tag=@default_block)
      block = get_block decode_block_tag(block_tag)
      bytes_to_hex Utils.zpad_int(block.get_storage_data(hex_to_bytes(address), hex_to_int(key)))
    end

    def handle_eth_getTransactionCount(address, block_tag=@default_block)
      block = get_block decode_block_tag(block_tag)
      int_to_hex block.get_nonce(hex_to_bytes(address))
    end

    def handle_eth_getBlockTransactionCountByHash(blockhash)
      block = get_block hex_to_bytes(blockhash)
      int_to_hex block.transaction_count
    end

    def handle_eth_getBlockTransactionCountByNumber(number)
      block = get_block hex_to_int(number)
      int_to_hex block.transaction_count
    end

    def handle_eth_getUncleCountByBlockHash(blockhash)
      block = get_block hex_to_bytes(blockhash)
      int_to_hex block.uncles.size
    end

    def handle_eth_getUncleCountByBlockNumber(number)
      block = get_block hex_to_int(number)
      int_to_hex block.uncles.size
    end

    def handle_eth_getCode(address, block_tag=@default_block)
      block = get_block decode_block_tag(block_tag)
      bytes_to_hex block.get_code(hex_to_bytes(address))
    end

    def handle_eth_sign(address, data)
      raise NotImplementedError
    end

    def handle_eth_sendTransaction(obj)
      to = hex_to_bytes(obj['to'] || '')

      startgas_hex = obj['gas'] || obj['startgas']
      startgas = startgas_hex ? hex_to_int(startgas_hex) : @default_startgas

      gas_price_hex = obj['gasPrice'] || obj['gasprice']
      gas_price = gas_price_hex ? hex_to_int(gas_price_hex) : @default_gas_price

      value = hex_to_int(obj['value'] || '')
      data = hex_to_bytes(obj['data'] || '')

      v = hex_to_int(obj['v'] || '')
      r = hex_to_int(obj['r'] || '')
      s = hex_to_int(obj['s'] || '')

      nonce = obj['nonce'] ? hex_to_int(obj['nonce']) : nil
      sender = hex_to_bytes(obj['from'] || @default_address)

      if v > 0
        raise "signed but no nonce provided" if nonce.nil?
        raise "invalid signature" unless r > 0 && s > 0
      else
        nonce ||= chain.chain.head_candidate.get_nonce(sender)

        addr = bytes_to_hex(sender)
        privkey = Account.test_accounts[addr]
        raise "no privkey found for address #{addr}" unless privkey
      end

      tx = Transaction.new nonce, gas_price, startgas, to, value, data, v, r, s
      # TODO

      puts "tx added: #{tx.log_dict}"
      bytes_to_hex tx.full_hash
    end

    def handle_eth_sendRawTransaction(data)
      raise NotImplementedError
    end

    def handle_eth_call(obj, block_tag='pending')
      success, output, _, _ = tentatively_execute obj, block_tag
      if success == 1
        bytes_to_hex output
      else
        false
      end
    end

    def handle_eth_estimateGas(obj, block_tag='pending')
      _, _, block, test_block = tentatively_execute obj, block_tag
      test_block.gas_used - block.gas_used
    end

    def handle_eth_getBlockByHash(blockhash, include_transactions)
      block = get_block hex_to_bytes(blockhash)
      encode_block block, include_transactions
    end

    def handle_eth_getBlockByNumber(block_tag, include_transactions)
      block = get_block decode_block_tag(block_tag)
      pending = block_tag == 'pending'
      encode_block block, include_transactions, pending
    end

    def handle_eth_getTransactionByHash(txhash)
      tx, block, index = @node.state.chain.index.get_transaction hex_to_bytes(txhash)

      if @node.state.chain.in_main_branch?(block)
        encode_tx tx, block, index, false
      else
        nil
      end
    rescue IndexError
      puts $!
      puts $!.backtrace.join("\n")
      nil
    end

    def handle_eth_getTransactionByBlockHashAndIndex(blockhash, index)
      block = get_block blockhash
      i = hex_to_int index

      tx = block.get_transaction i
      pending = blockhash == 'pending'
      encode_tx tx, block, i, pending
    rescue IndexError
      nil
    end

    def handle_eth_getTransactionReceipt(txhash)
      tx, block, index = @node.state.chain.index.get_transaction hex_to_bytes(txhash)

      return nil unless @node.state.chain.in_main_branch?(block)

      receipt = block.get_receipt index
      h = {
        transactionHash: bytes_to_hex(tx.full_hash),
        transactionIndex: int_to_hex(index),
        blockHash: bytes_to_hex(block.full_hash),
        blockNumber: int_to_hex(block.number),
        cumulativeGasUsed: int_to_hex(receipt.gas_used),
        contractAddress: tx.creates ? bytes_to_hex(tx.creates) : nil
      }

      if index == 0
        h[:gasUsed] = int_to_hex(receipt.gas_used)
      else
        prev_receipt = block.get_receipt(index - 1)
        raise "invalid previous receipt" unless prev_receipt.gas_used < receipt.gas_used
        h[:gasUsed] = int_to_hex(receipt.gas_used - prev_receipt.gas_used)
      end

      logs = receipt.logs.each_with_index.map do |log, i|
        {
          log: log,
          log_idx: i,
          block: block,
          txhash: tx.full_hash,
          tx_idx: index,
          pending: false
        }
      end
      h[:logs] = encode_loglist logs

      h
    rescue IndexError
      nil
    end

    def handle_eth_getUncleByBlockHashAndIndex(blockhash, index)
      return nil if blockhash == 'pending'

      block = get_block blockhash
      i = hex_to_int index

      uncle = block.uncles[i]
      return nil unless uncle

      encode_block uncle, false, false, true
    end

    def handle_eth_getUncleByBlockNumberAndIndex(block_tag, index)
      return nil if block_tag == 'pending'

      block = get_block decode_block_tag(block_tag)
      i = hex_to_int index

      uncle = block.uncles[i]
      return nil unless uncle

      encode_block uncle, false, false, true
    end

    def handle_eth_getCompilers
      get_compilers.keys
    end

    def handle_eth_compileSolidity(code)
      compiler, method = get_compilers[:solidity]
      compiler.send method, code
    end

    def handle_eth_compileLLL(code)
      compiler, method = get_compilers[:lll]
      bytes_to_hex compiler.send(method, code)
    end

    def handle_eth_compileSerpent(code)
      compiler, method = get_compilers[:serpent]
      bytes_to_hex compiler.send(method, code)
    end

    def handle_eth_newFilter(obj)
      int_to_hex LogFilter.create(obj, @node.state.chain)
    end

    def handle_eth_newBlockFilter
      int_to_hex BlockFilter.create(@node.state.chain)
    end

    def handle_eth_newPendingTransactionFilter
      int_to_hex PendingTransactionFilter.create(@node.state.chain)
    end

    def handle_eth_uninstallFilter(id)
      id = hex_to_int id

      if Filter.include?(id)
        Filter.delete id
        true
      else
        false
      end
    end

    def handle_eth_getFilterChanges(id)
      id = hex_to_int id
      raise ArgumentError, "unknown filter id" unless Filter.include?(id)

      filter = Filter.find id
      if [BlockFilter,PendingTransactionFilter].include?(filter.class)
        filter.check.map {|block_or_tx| bytes_to_hex block_or_tx.full_hash }
      elsif filter.instance_of?(LogFilter)
        encode_loglist filter.new_logs
      else
        raise "invalid filter"
      end
    end

    def handle_eth_getFilterLogs(id)
      id = hex_to_int id
      raise ArgumentError, "unknown filter id" unless Filter.include?(id)

      filter = Filter.find id
      encode_loglist filter.logs
    end

    def handle_eth_getLogs(obj)
      filter = LogFilter.new(obj, @node.state.chain)
      encode_loglist filter.logs
    end

    def handle_eth_getWork
      raise NotImplementedError
    end

    def handle_eth_submitWork
      raise NotImplementedError
    end

    def handle_eth_submitHashrate
      raise NotImplementedError
    end

    def handle_db_putString(db_name, k, v)
      raise NotImplementedError
    end

    def handle_db_getString(db_name, k)
      raise NotImplementedError
    end

    def handle_db_putHex(db_name, k, v)
      raise NotImplementedError
    end

    def handle_db_getHex(db_name, k)
      raise NotImplementedError
    end

    def tentatively_execute(obj, block_tag)
      raise ArgumentError, 'first parameter must be an object' unless obj.instance_of?(Hash)

      raise ArgumentError, 'missing message receiver (to)' unless obj['to']
      to = hex_to_bytes obj['to']

      block = get_block decode_block_tag(block_tag)
      snapshot_before = block.snapshot
      tx_root_before = snapshot_before[:txs].root_hash

      if block.has_parent?
        parent = block.get_parent
        test_block = Block.build_from_parent parent, block.coinbase, timestamp: block.timestamp

        block.get_transactions.each do |tx|
          success, output = test_block.apply_transaction tx
          raise "failed to prepare test block" if success == 0
        end
      else
        env = Env.new block.db
        test_block = Block.genesis env

        original = snapshot_before.dup
        original.delete :txs
        original = Marshal.load Marshal.dump(original) # deepcopy
        original[:txs] = Ethereum::Trie.new snapshot_before[:txs].db, snapshot_before[:txs].root_hash

        test_block = Block.genesis env
        test_block.revert original
      end

      startgas = obj['gas'] ? hex_to_int(obj['gas']) : (test_block.gas_limit - test_block.gas_used)
      gas_price = obj['gasPrice'] ? hex_to_int(obj['gasPrice']) : 0
      value = obj['value'] ? hex_to_int(obj['value']) : 0
      data = obj['data'] ? hex_to_bytes(obj['data']) : ''
      sender = obj['from'] ? hex_to_bytes(obj['from']) : Ethereum::Address::ZERO

      nonce = test_block.get_nonce sender
      tx = Transaction.new nonce, gas_price, startgas, to, value, data
      tx.sender = sender

      begin
        # FIXME: tx.check_low_s will raise exception if block is after homestead fork
        success, output = test_block.apply_transaction tx
      rescue Ethereum::InvalidTransaction
        puts $!
        puts $!.backtrace[0,10].join("\n")
        success = 0
      end

      snapshot_after = block.snapshot
      raise "real data should not be changed" unless snapshot_after == snapshot_before
      raise "real data should not be changed" unless snapshot_after[:txs].root_hash == tx_root_before

      return success, output, block, test_block
    end

  end

end
end
