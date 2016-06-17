module Reth
module JSONRPC

  module Helper

    def chain
      @node.services.chain
    end

    def peermanager
      @node.services.peermanager
    end

    def discovery
      @node.services.discovery
    end

    def bytes_to_hex(bytes)
      "0x#{Utils.encode_hex(bytes)}"
    end

    def hex_to_bytes(hex)
      hex = hex[2..-1] if hex[0,2] == '0x'
      Utils.decode_hex hex
    end

    def int_to_hex(n)
      hex = Utils.encode_hex Utils.int_to_big_endian(n)
      hex = hex.gsub(/\A0+/, '')
      "0x#{hex.empty? ? '0' : hex}"
    end

    def hex_to_int(hex)
      hex = hex[2..-1] if hex[0,2] == '0x'
      hex = '0' + hex if hex.size % 2 == 1 # padding left to make size even
      Utils.big_endian_to_int hex_to_bytes(hex)
    end

    def get_ivar_value(ivar)
      raise "operation failed: #{ivar.reason}" if ivar.rejected?
      ivar.value
    end

    def get_block(id)
      case id
      when 'latest'
        chain.chain.head
      when 'earliest'
        chain.chain.genesis
      when 'pending'
        chain.chain.head_candidate
      when Integer
        hash = chain.chain.index.get_block_by_number id
        chain.chain.get hash
      when String
        id = hex_to_bytes(id) if id[0,2] == '0x'
        chain.chain.get id
      else
        raise "unknown block id: #{id}"
      end
    end

    def decode_block_tag(tag)
      return tag if tag.nil?
      return tag if %w(latest earliest pending).include?(tag)
      return hex_to_int(tag)
    end

    def encode_block(block, include_transactions=false, pending=false, is_header=false)
      raise ArgumentError, "cannot include transactions for header" if include_transactions && is_header

      h = {
        number: pending ? nil : int_to_hex(block.number),
        hash: pending ? nil : bytes_to_hex(block.full_hash),
        parentHash: bytes_to_hex(block.prevhash),
        nonce: pending ? nil : bytes_to_hex(block.nonce),
        sha3Uncles: bytes_to_hex(block.uncles_hash),
        logsBloom: pending ? nil : bytes_to_hex(Utils.int_to_big_endian(block.bloom)),
        transactionsRoot: bytes_to_hex(block.tx_list_root),
        stateRoot: bytes_to_hex(block.state_root),
        miner: pending ? nil : bytes_to_hex(block.coinbase),
        difficulty: int_to_hex(block.difficulty),
        extraData: bytes_to_hex(block.extra_data),
        gasLimit: int_to_hex(block.gas_limit),
        gasUsed: int_to_hex(block.gas_used),
        timestamp: int_to_hex(block.timestamp)
      }

      unless is_header
        h[:totalDifficulty] = int_to_hex(block.chain_difficulty)
        h[:size] = int_to_hex(RLP.encode(block).size)
        h[:uncles] = block.uncles.map {|u| bytes_to_hex(u.full_hash) }

        if include_transactions
          h[:transactions] = block.get_transactions.each_with_index.map {|tx, i| encode_tx(tx, block, i, pending) }
        else
          h[:transactions] = block.get_transactions.map {|tx| bytes_to_hex(tx.full_hash) }
        end
      end

      h
    end

    def encode_tx(transaction, block, i, pending)
      {
        hash: bytes_to_hex(transaction.full_hash),
        nonce: int_to_hex(transaction.nonce),
        blockHash: bytes_to_hex(block.full_hash),
        blockNumber: pending ? nil : int_to_hex(block.number),
        transactionIndex: int_to_hex(i),
        from: bytes_to_hex(transaction.sender),
        to: bytes_to_hex(transaction.to),
        value: int_to_hex(transaction.value),
        gasPrice: int_to_hex(transaction.gasprice),
        gas: int_to_hex(transaction.startgas),
        input: bytes_to_hex(transaction.data)
      }
    end

    def encode_loglist(logs)
      logs.map do |l|
        {
          logIndex: l[:pending] ? nil : int_to_hex(l[:log_idx]),
          transactionIndex: l[:pending] ? nil : int_to_hex(l[:tx_idx]),
          transactionHash: l[:pending] ? nil : bytes_to_hex(l[:txhash]),
          blockHash: l[:pending] ? nil : bytes_to_hex(l[:block].full_hash),
          blockNumber: l[:pending] ? nil : int_to_hex(l[:block].number),
          address: bytes_to_hex(l[:log].address),
          data: bytes_to_hex(l[:log].data),
          topics: l[:log].topics.map {|t| bytes_to_hex Utils.zpad_int(t) },
          type: l[:pending] ? 'pending' : 'mined'
        }
      end
    end

    def get_compilers
      return @compilers if @compilers

      @compilers = {}

      if serpent = Ethereum::Tester::Language.all[:serpent]
        @compilers[:serpent] = [serpent, :compile]
        @compilers[:lll] = [serpent, :compile_lll]
      end

      if solidity = Ethereum::Tester::Language.all[:solidity]
        @compilers[:solidity] = [solidity, :compile_rich]
      end

      @compilers
    end

  end

end
end
