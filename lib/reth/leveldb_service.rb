# -*- encoding : ascii-8bit -*-

module Reth

  class LevelDBService < ::DEVp2p::Service
    name 'leveldb'

    attr :db # implement DB::BaseDB interface

    def initialize(app)
      super(app)
      @db = DB::LevelDB.new File.join(app.config[:data_dir], 'leveldb')
    end

    def start
      # do nothing
    end

    def stop
      # do nothing
    end

    def get(k)
      @db.get(k)
    rescue KeyError
      nil
    end

    def put(k, v)
      @db.put(k, v)
    end

    def commit
      @db.commit
    end

    def delete(k)
      @db.delete(k)
    end

    def include?(k)
      @db.include?(k)
    end
    alias has_key? include?

    def inc_refcount(k, v)
      put(k, v)
    end

    def dec_refcount(k)
      # do nothing
    end

    def revert_refcount_changes(epoch)
      # do nothing
    end

    def commit_refcount_changes(epoch)
      # do nothing
    end

    def cleanup(epoch)
      # do nothing
    end

    def put_temporarily(k, v)
      inc_refcount(k, v)
      dec_refcount(k)
    end

    private

    def logger
      @logger ||= Logger.new 'db'
    end

  end

end
