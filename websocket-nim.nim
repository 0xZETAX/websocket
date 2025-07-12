# Nim WebSocket Client
import asyncdispatch, websocket, uri, strutils, json, times

type
  WebSocketClient* = ref object
    ws: WebSocket
    url: string
    connected: bool

proc newWebSocketClient*(url: string): WebSocketClient =
  ## Create a new WebSocket client
  result = WebSocketClient(url: url, connected: false)

proc onOpen*(client: WebSocketClient) {.async.} =
  ## Called when connection is opened - override this
  echo "WebSocket connection opened"

proc onMessage*(client: WebSocketClient, message: string) {.async.} =
  ## Called when message is received - override this
  echo "Received: ", message

proc onClose*(client: WebSocketClient) {.async.} =
  ## Called when connection is closed - override this
  echo "WebSocket connection closed"

proc onError*(client: WebSocketClient, error: string) {.async.} =
  ## Called when error occurs - override this
  echo "WebSocket error: ", error

proc connect*(client: WebSocketClient) {.async.} =
  ## Connect to WebSocket server
  try:
    echo "Connecting to ", client.url
    client.ws = await newWebSocket(client.url)
    client.connected = true
    echo "Connected to WebSocket server"
    await client.onOpen()
  except Exception as e:
    await client.onError(e.msg)
    raise

proc send*(client: WebSocketClient, message: string) {.async.} =
  ## Send a text message
  if client.connected and not client.ws.isNil:
    await client.ws.send(message)
    echo "Sent: ", message
  else:
    echo "Not connected, cannot send message"

proc sendJson*(client: WebSocketClient, data: JsonNode) {.async.} =
  ## Send a JSON message
  await client.send($data)

proc listen*(client: WebSocketClient) {.async.} =
  ## Listen for incoming messages
  try:
    while client.connected and not client.ws.isNil:
      let message = await client.ws.receiveStrPacket()
      await client.onMessage(message)
  except WebSocketClosedError:
    client.connected = false
    await client.onClose()
  except Exception as e:
    await client.onError(e.msg)

proc close*(client: WebSocketClient) {.async.} =
  ## Close the WebSocket connection
  if not client.ws.isNil:
    client.ws.close()
    client.connected = false
    await client.onClose()

proc isConnected*(client: WebSocketClient): bool =
  ## Check if client is connected
  return client.connected

# Custom WebSocket client with event handlers
type
  CustomWebSocketClient* = ref object of WebSocketClient

proc newCustomWebSocketClient*(url: string): CustomWebSocketClient =
  result = CustomWebSocketClient(url: url, connected: false)

method onOpen*(client: CustomWebSocketClient) {.async.} =
  echo "Custom: WebSocket connection established!"

method onMessage*(client: CustomWebSocketClient, message: string) {.async.} =
  echo "Custom: Processing message: ", message
  
  # Echo the message back with timestamp
  let response = %*{
    "type": "echo",
    "original": message,
    "timestamp": now().toTime().toUnix()
  }
  await client.sendJson(response)

method onClose*(client: CustomWebSocketClient) {.async.} =
  echo "Custom: Connection has been closed"

method onError*(client: CustomWebSocketClient, error: string) {.async.} =
  echo "Custom: An error occurred: ", error

# Simple usage example
proc basicExample() {.async.} =
  echo "=== Basic WebSocket Client Example ==="
  
  let client = newWebSocketClient("ws://localhost:8080")
  
  # Connect to server
  await client.connect()
  
  # Start listening in background
  asyncCheck client.listen()
  
  # Send some messages
  await sleepAsync(1000)  # Wait 1 second
  await client.send("Hello from Nim!")
  
  # Send JSON message
  let jsonMsg = %*{
    "type": "greeting",
    "message": "Hello from Nim JSON!",
    "timestamp": now().toTime().toUnix()
  }
  await client.sendJson(jsonMsg)
  
  # Keep connection alive
  await sleepAsync(5000)  # Wait 5 seconds
  
  # Close connection
  await client.close()
  echo "Basic example completed"

# Custom client example
proc customExample() {.async.} =
  echo "\n=== Custom WebSocket Client Example ==="
  
  let client = newCustomWebSocketClient("ws://localhost:8080")
  
  await client.connect()
  asyncCheck client.listen()
  
  await sleepAsync(1000)
  await client.send("Test message for custom client")
  
  await sleepAsync(3000)
  await client.close()
  echo "Custom example completed"

# Ping-pong example
proc pingPongExample() {.async.} =
  echo "\n=== Ping-Pong Example ==="
  
  let client = newWebSocketClient("ws://localhost:8080")
  
  # Override message handler for ping-pong
  client.onMessage = proc(client: WebSocketClient, message: string) {.async.} =
    echo "Received: ", message
    if message == "ping":
      await client.send("pong")
    elif message == "pong":
      echo "Got pong response!"
  
  await client.connect()
  asyncCheck client.listen()
  
  # Send ping every 2 seconds
  for i in 1..3:
    await sleepAsync(2000)
    await client.send("ping")
  
  await sleepAsync(2000)
  await client.close()
  echo "Ping-pong example completed"

# Simple send function
proc sendSimpleMessage*(url: string, message: string) {.async.} =
  echo "Sending simple message to ", url
  
  let client = newWebSocketClient(url)
  await client.connect()
  
  await sleepAsync(500)  # Wait for connection to stabilize
  await client.send(message)
  
  await sleepAsync(1000)  # Wait for response
  await client.close()

# Main execution
proc main() {.async.} =
  echo "Nim WebSocket Client Examples"
  echo "============================="
  
  try:
    await basicExample()
    await customExample()
    await pingPongExample()
    
    echo "\nAll examples completed successfully!"
  except Exception as e:
    echo "Error: ", e.msg

# Run the examples
when isMainModule:
  # Check command line arguments
  if paramCount() > 0:
    case paramStr(1):
    of "basic":
      waitFor basicExample()
    of "custom":
      waitFor customExample()
    of "ping":
      waitFor pingPongExample()
    of "simple":
      if paramCount() > 1:
        waitFor sendSimpleMessage("ws://localhost:8080", paramStr(2))
      else:
        waitFor sendSimpleMessage("ws://localhost:8080", "Simple message from Nim")
    else:
      echo "Unknown command: ", paramStr(1)
      echo "Available commands: basic, custom, ping, simple [message]"
  else:
    waitFor main()

# To compile and run:
# nim c -r websocket-nim.nim
# nim c -r websocket-nim.nim basic
# nim c -r websocket-nim.nim custom
# nim c -r websocket-nim.nim ping
# nim c -r websocket-nim.nim simple "Hello World"
#
# To install websocket package:
# nimble install websocket