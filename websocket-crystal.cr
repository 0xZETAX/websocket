# Crystal WebSocket Client
require "http/web_socket"
require "uri"

class WebSocketClient
  @ws : HTTP::WebSocket?
  @url : String
  @connected : Bool = false

  def initialize(@url : String)
  end

  def connect
    uri = URI.parse(@url)
    host = uri.host || "localhost"
    port = uri.port || 80
    path = uri.path || "/"

    puts "Connecting to #{@url}"

    @ws = HTTP::WebSocket.new(host, path, port)
    
    if ws = @ws
      @connected = true
      puts "Connected to WebSocket server"

      # Set up event handlers
      ws.on_message do |message|
        puts "Received: #{message}"
        on_message(message)
      end

      ws.on_close do |close_code, message|
        puts "Connection closed: #{close_code} - #{message}"
        @connected = false
        on_close(close_code, message)
      end

      ws.on_ping do |message|
        puts "Received ping: #{message}"
        ws.pong(message)
      end

      ws.on_pong do |message|
        puts "Received pong: #{message}"
      end

      # Start the WebSocket in a fiber
      spawn do
        begin
          ws.run
        rescue ex
          puts "WebSocket error: #{ex.message}"
          @connected = false
          on_error(ex)
        end
      end

      on_open()
    end
  end

  def send(message : String)
    if @connected && (ws = @ws)
      ws.send(message)
      puts "Sent: #{message}"
    else
      puts "Not connected, cannot send message"
    end
  end

  def send_json(data : Hash)
    json_string = data.to_json
    send(json_string)
  end

  def close
    if ws = @ws
      ws.close
      @ws = nil
      @connected = false
    end
  end

  def connected?
    @connected
  end

  # Event handlers - override these in your implementation
  def on_open
    # Override this method
  end

  def on_message(message : String)
    # Override this method
  end

  def on_close(close_code : HTTP::WebSocket::CloseCode, message : String)
    # Override this method
  end

  def on_error(error : Exception)
    # Override this method
  end
end

# Custom WebSocket client with event handlers
class CustomWebSocketClient < WebSocketClient
  def on_open
    puts "Custom: WebSocket connection opened!"
  end

  def on_message(message : String)
    puts "Custom: Processing message: #{message}"
    
    # Echo the message back with a prefix
    if connected?
      send("Echo: #{message}")
    end
  end

  def on_close(close_code : HTTP::WebSocket::CloseCode, message : String)
    puts "Custom: Connection closed with code #{close_code}"
  end

  def on_error(error : Exception)
    puts "Custom: Error occurred: #{error.message}"
  end
end

# Usage example
def main
  client = WebSocketClient.new("ws://localhost:8080")
  
  # Connect to server
  client.connect
  
  # Wait for connection to establish
  sleep(1)
  
  # Send messages
  if client.connected?
    client.send("Hello from Crystal!")
    
    # Send JSON message
    client.send_json({
      "type" => "greeting",
      "message" => "Hello from Crystal JSON!",
      "timestamp" => Time.utc.to_unix
    })
  end
  
  # Keep connection alive
  sleep(5)
  
  # Close connection
  client.close
  puts "WebSocket client finished"
end

# Example with custom client
def custom_client_example
  puts "\nRunning custom client example:"
  
  client = CustomWebSocketClient.new("ws://localhost:8080")
  client.connect
  
  sleep(1)
  
  if client.connected?
    client.send("Test message for custom client")
  end
  
  sleep(3)
  client.close
end

# Simple WebSocket sender function
def send_simple_message(url : String, message : String)
  puts "Sending simple message to #{url}"
  
  uri = URI.parse(url)
  host = uri.host || "localhost"
  port = uri.port || 80
  path = uri.path || "/"

  ws = HTTP::WebSocket.new(host, path, port)
  
  connected = false
  
  ws.on_message do |response|
    puts "Received response: #{response}"
  end
  
  spawn do
    begin
      ws.run
    rescue ex
      puts "Error: #{ex.message}"
    end
  end
  
  # Wait a moment for connection
  sleep(0.5)
  
  # Send message
  ws.send(message)
  puts "Sent: #{message}"
  
  # Wait for response
  sleep(2)
  
  # Close
  ws.close
end

# Run examples
if ARGV.size > 0 && ARGV[0] == "custom"
  custom_client_example
elsif ARGV.size > 0 && ARGV[0] == "simple"
  send_simple_message("ws://localhost:8080", "Simple message from Crystal")
else
  main
end

# To compile and run:
# crystal build websocket-crystal.cr
# ./websocket-crystal
#
# Or run directly:
# crystal run websocket-crystal.cr
# crystal run websocket-crystal.cr -- custom
# crystal run websocket-crystal.cr -- simple