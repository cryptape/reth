module Reth
module JSONRPC

  class App < Sinatra::Base

    configure do
      enable :logging
    end

    CORS_ORIGIN = "http://localhost:8080"

    options "*" do
      response.headers["Allow"] = "POST,OPTIONS"
      response.headers["Access-Control-Allow-Headers"] = "X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept"
      response.headers["Access-Control-Allow-Origin"] = "http://localhost:8080"
      response.headers["Access-Control-Allow-Methods"] = "POST"

      200
    end

    post '/' do
      response.headers["Access-Control-Allow-Origin"] = CORS_ORIGIN

      begin
        data = JSON.parse request.body.read
        puts "Params: #{data.inspect}"

        result = if data.instance_of?(Array)
                   data.map {|d| dispatch d }
                 else
                   dispatch data
                 end

        json result
      rescue JSON::ParserError
        puts $!
        puts $!.backtrace[0,10].join("\n")
        json jsonrpc: '2.0', error: $!
      end
    end

    def initialize(node)
      @node = node

      @default_block = 'latest'
      @default_address = Account.test_accounts.keys.first
      @default_startgas = 500 * 1000
      @default_gas_price = 60.shannon

      super()
    end

    private

    include Handler

    def dispatch(data)
      # TODO: filter injection, validate method names
      result = send :"handle_#{data['method']}", *data['params']

      {jsonrpc: data['jsonrpc'], id: data['id'], result: result}
    rescue NoMethodError
      if $!.message =~ /handle_([a-zA-Z_]+)/
        {jsonrpc: '2.0', id: data['id'], error: "jsonrpc method not defined: #{$1}"}
      else
        puts $!
        puts $!.backtrace[0,10].join("\n")
        {jsonrpc: data['jsonrpc'], id: data['id'], error: $!}
      end
    rescue
      puts $!
      puts $!.backtrace[0,10].join("\n")
      {jsonrpc: data['jsonrpc'], id: data['id'], error: $!}
    end

  end

end
end
