module Reth
module JSONRPC

  class Service < ::DEVp2p::Service

    class <<self
      def register_with_app(app)
        config = default_config[:jsonrpc]
        app.register_service self, app, config[:host], config[:port]
      end
    end

    name 'jsonrpc'
    default_config(
      jsonrpc: {
        host: '127.0.0.1',
        port: 8333
      }
    )

    def initialize(app, host, port)
      super(app)

      @app = app
      @host = host
      @port = port
    end

    def start
      @server = Server.new @app, @host, @port
      @server.async.start
    end

  end

end
end
