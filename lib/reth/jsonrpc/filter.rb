module Reth
module JSONRPC

  class Filter
    class <<self
      def next_id
        @next_id ||= 0
        @next_id += 1
      end

      def map
        @map ||= {}
      end

      def find(id)
        map[id]
      end

      def delete(id)
        map.delete id
      end

      def include?(id)
        map.include?(id)
      end
    end
  end

  class LogFilter

    class <<self
      def create(obj, chain)
        f = new obj, chain
        id = Filter.next_id
        Filter.map[id] = f
        id
      end
    end

    include Helper

    def initialize(obj, chain)
      @chain = chain
      @first_block, @last_block, @addresses, @topics = parse_obj obj

      @last_head = @chain.head
      @last_block_checked = nil

      @log_dict = {}
    end

    def check
      first, last = get_from_to @first_block, @last_block
      first = [@last_head.number + 1, first].min if @first_block.is_a?(String)
      raise "first must not be greater than last" unless first <= last

      if @last_block_checked
        first = [@last_block_checked.number + 1, first].max
        return {} if first > last
      end

      blocks_to_check = []
      (first...last).each do |n|
        blocks_to_check.push @chain.index.get_block_by_number(n)
      end

      head = @chain.head
      head_candidate = @chain.head_candidate

      if last == head_candidate.number
        blocks_to_check.push head_candidate
      else
        blocks_to_check.push @chain.get(@chain.index.get_block_by_number(last))
      end

      int32 = RLP::Sedes::BigEndianInt.new 32

      new_logs = {}
      blocks_to_check.each_with_index do |block, i|
        unless [Ethereum::Block, Ethereum::CachedBlock].include?(block.class)
          # must be blockhash
          bloom = @chain.get_bloom block

          if @addresses
            pass_address_check = @addresses.any? {|addr| Ethereum::Bloom.query(bloom, addr) }
            next unless pass_address_check
          end

          topics = (@topics || []).map {|t| int32.serialize(t) }
          topic_bloom = Ethereum::Bloom.from_array topics
          next if Ethereum::Bloom.combine(bloom, topic_bloom) != bloom

          block = @chain.get block
        end

        r_idx = nil
        l_idx = nil
        log = nil
        block.get_receipts.each_with_index do |receipt, ri|
          r_idx = ri

          receipt.logs.each_with_index do |_log, li|
            log = _log
            l_idx = li

            next if @addresses && !@addresses.include?(log.address)

            if @topics
              topic_match = log.topics.size >= @topics.size
              next unless topic_match

              @topics.zip(log.topics).each do |filter_topic, log_topic|
                if filter_topic && filter_topic != log_topic
                  topic_match = false
                  break
                end
              end
              next unless topic_match
            end

            tx = block.get_transaction r_idx
            id = Ethereum::Utils.keccak256 "#{tx.full_hash}#{l_idx}"
            pending = block == head_candidate
            new_logs[id] = {
              log: log,
              log_idx: l_idx,
              block: block,
              txhash: tx.full_hash,
              tx_idx: r_idx
            }
          end
        end
      end

      @last_block_checked = if blocks_to_check.last != head_candidate
                              blocks_to_check.last
                            else
                              blocks_to_check.size >= 2 ? blocks_to_check[-2] : nil
                            end

      if @last_block_checked && ![Ethereum::Block, Ethereum::CachedBlock].include?(@last_block_checked.class)
        @last_block_checked = @chain.get @last_block_checked
      end

      actually_new_ids = new_logs.keys - @log_dict.keys
      @log_dict.merge! new_logs

      actually_new_ids.map {|id| [id, new_logs[id]] }.to_h
    end

    def logs
      check
      @log_dict.values
    end

    def new_logs
      check.values
    end

    def to_s
      "<Filter(addressed=#{@addresses}, topics=#{@topics}, first=#{@first_block}, last=#{@last_block})>"
    end

    private

    def parse_obj(obj)
      raise ArgumentError, 'obj must be a Hash' unless obj.instance_of?(Hash)

      addresses = case obj['address']
                  when String
                    [hex_to_bytes(obj['address'])]
                  when Array
                    obj['address'].map {|addr| hex_to_bytes(addr) }
                  when NilClass
                    nil
                  else
                    raise ArgumentError, "address must be String or Array of Strings"
                  end

      topics = nil
      if obj.has_key?('topics')
        topics = []
        obj['topics'].each do |t|
          if t
            topics.push(Ethereum::Utils.big_endian_to_int hex_to_bytes(t))
          else
            topics.push(nil)
          end
        end
      end

      from_block = decode_block_tag(obj['fromBlock'] || 'latest')
      to_block = decode_block_tag(obj['toBlock'] || 'latest')

      from, to = get_from_to from_block, to_block
      raise ArgumentError, 'fromBlock must not be newer than toBlock' if from > to

      return from_block, to_block, addresses, topics
    end

    def get_from_to(from_block, to_block)
      block_tags = {
        'earliest' => 0,
        'latest' => @chain.head.number,
        'pending' => @chain.head_candidate.number
      }
      from = from_block.is_a?(Integer) ? from_block : block_tags[from_block]
      to = to_block.is_a?(Integer) ? to_block : block_tags[to_block]

      return from, to
    end

  end

  class BlockFilter

    class <<self
      def create(chain)
        f = new chain
        id = Filter.next_id
        Filter.map[id] = f
        id
      end
    end

    def initialize(chain)
      @chain = chain
      @latest_block = chain.head
    end

    def check
      new_blocks = []
      block = @chain.head

      while block.number > @latest_block.number
        new_blocks.push block
        block = block.get_parent
      end

      puts "previous latest block not in current chain!" if block != @latest_block
      @latest_block = new_blocks.first if new_blocks.size > 0

      new_blocks.reverse
    end

  end

  class PendingTransactionFilter

    class <<self
      def create(chain)
        f = new chain
        id = Filter.next_id
        Filter.map[id] = f
        id
      end
    end

    def initialize(chain)
      @chain = chain
      @latest_block = @chain.head_candidate
      @reported_txs = []
    end

    def check
      head_candidate = @chain.head_candidate
      pending_txs = head_candidate.get_transactions
      new_txs = pending_txs.select {|tx| !@reported_txs.include?(tx.full_hash) }

      block = head_candidate.get_parent
      while block.number >= @latest_block.number
        block.get_transactions.reverse.each do |tx|
          new_txs.push(tx) unless @reported_txs.include?(tx.full_hash)
        end

        block = block.get_parent
      end

      @latest_block = head_candidate
      @reported_txs = pending_txs.map(&:full_hash)

      new_txs.reverse
    end

  end

end
end
