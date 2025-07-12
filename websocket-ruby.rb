# Ruby WebSocket Client
require 'websocket-client-simple'

class WebSocketClient
  def initialize(url)
    @url = url
    @ws = nil
  end

  def connect
    @ws = WebSocket::Client::Simple.connect(@url)

    @ws.on :open do |event|
      puts "Connected to WebSocket server"
      on_open(event)
    end

    @ws.on :message do |event|
      puts "Received: #{event.data}"
      on_message(event.data)
    end

    @ws.on :close do |event|
      puts "Connection closed"
      on_close(event)
    end

    @ws.on :error do |event|
      puts "Error: #{event.data}"
      on_error(event)
    end
  end

  def send(message)
    if @ws
      @ws.send(message)
      puts "Sent: #{message}"
    end
  end

  def close
    @ws.close if @ws
  end

  # Override these methods in your implementation
  def on_open(event)
  end

  def on_message(message)
  end

  def on_close(event)
  end

  def on_error(event)
  end
end

# Usage example
client = WebSocketClient.new('ws://localhost:8080')
client.connect

# Send a message after connection
sleep(1)
client.send('Hello from Ruby!')

# Keep connection alive
sleep(5)
client.close