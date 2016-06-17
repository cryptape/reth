module Reth
module JSONRPC

  class Server
    include Concurrent::Async

    def initialize(app, host, port)
      super()

      @app  = app
      @host = host
      @port = port
    end

    def start
      Rack::Handler::WEBrick.run App.new(@app), Host: @host, Port: @port
    rescue
      puts $!
      puts $!.backtrace[0,10].join("\n")
    end
  end

end
end
