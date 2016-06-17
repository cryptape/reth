# -*- encoding : ascii-8bit -*-

module Reth

  class DBService < ::DEVp2p::Service
    include DB::BaseDB

    name 'db'
    default_config(
      db: {
        implementation: 'LevelDB'
      }
    )

    def initialize(app)
      super(app)
      @db_service = LevelDBService.new(app)
    end

    def start
      @db_service.async.start
    end

    def stop
      @db_service.async.stop
    end

    def db
      @db_service.db
    end

    def get(k)
      ivar = @db_service.await.get(k)
      if ivar.rejected?
        raise ivar.reason
      else
        ivar.value
      end
    end

    def put(k, v)
      @db_service.async.put(k, v)
    end

    def commit
      @db_service.async.commit
    end

    def delete(k)
      @db_service.async.delete(k)
    end

    def include?(k)
      ivar = @db_service.await.include?(k)
      if ivar.rejected?
        raise ivar.reason
      else
        ivar.value
      end
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

  end

end
