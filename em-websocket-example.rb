require 'rubygems'
require 'em-websocket'
require 'goliath'
require 'goliath/api'
require 'goliath/runner'
require 'goliath/connection'
require 'goliath/rack/async_middleware'
require 'goliath/rack/builder'
require 'goliath/rack/default_response_format'
require 'goliath/rack/default_mime_type'
require 'goliath/rack/formatters/json'
require 'goliath/rack/params'
require 'logger'

class Upload < Goliath::API
  use Goliath::Rack::DefaultMimeType
  use Goliath::Rack::Params
  def response(env)
    users = env.config[:websockets]
    if target = users["/#{params['target']}"]
      target.send params['message']
    end
    [200, {"Content-Type" => "text/plain"}, ["OK"]]
  end

end

class Router < Goliath::API
  map "/notify", Upload
end

class NotifyApi < Goliath::Connection
  def initialize(websockets)
    @websockets = websockets
  end

  def post_init
    Goliath.env = :production
    @options    = {}
    @config     = {websockets: @websockets}
    @status     = {}
    @logger     = Logger.new(STDOUT)
    @app        = Goliath::Rack::Builder.build(Router, Router.new)
    super
  end
end

websockets = {}

EventMachine.run {

  EM.start_server("0.0.0.0", 9000, NotifyApi, websockets) do |c|
    #puts "goliath started"
  end


  EventMachine::WebSocket.start(:host => "0.0.0.0", :port => 8080) do |ws|
    ws.onopen {
      #puts "WebSocket connection open"
      #puts ws.request.inspect
      websockets[ws.request['path']] = ws

      # publish message to the client
      ws.send "Hello Client"
    }

    ws.onclose do
      websockets.delete(ws.request['path'])
      puts "Connection closed"
    end

    ws.onmessage { |msg|
      puts "Recieved message: #{msg}"
      ws.send "Pong: #{msg}"
    }
  end
}
