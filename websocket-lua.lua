-- Lua WebSocket Client (using lua-websockets)
local websocket = require("websocket")
local socket = require("socket")

-- WebSocket Client class
local WebSocketClient = {}
WebSocketClient.__index = WebSocketClient

function WebSocketClient:new(url)
    local obj = {
        url = url,
        ws = nil,
        connected = false
    }
    setmetatable(obj, self)
    return obj
end

function WebSocketClient:connect()
    print("Connecting to " .. self.url)
    
    -- Parse URL (simplified for localhost)
    local host = "localhost"
    local port = 8080
    local path = "/"
    
    -- Create WebSocket connection
    self.ws = websocket.client.sync({
        timeout = 5
    })
    
    local ok, err = self.ws:connect("ws://" .. host .. ":" .. port .. path)
    
    if not ok then
        print("Connection failed: " .. (err or "unknown error"))
        return false
    end
    
    self.connected = true
    print("Connected to WebSocket server")
    self:on_open()
    return true
end

function WebSocketClient:send(message)
    if self.connected and self.ws then
        local ok, err = self.ws:send(message)
        if ok then
            print("Sent: " .. message)
        else
            print("Send failed: " .. (err or "unknown error"))
        end
        return ok
    else
        print("Not connected, cannot send message")
        return false
    end
end

function WebSocketClient:send_json(data)
    local json = require("json") -- Assuming a JSON library is available
    local json_string = json.encode(data)
    return self:send(json_string)
end

function WebSocketClient:receive()
    if not self.connected or not self.ws then
        return nil, "not connected"
    end
    
    local message, opcode, was_clean, code, reason = self.ws:receive()
    
    if message then
        print("Received: " .. message)
        self:on_message(message)
        return message
    elseif opcode == websocket.CLOSE then
        print("Connection closed: " .. (reason or ""))
        self.connected = false
        self:on_close(code, reason)
        return nil, "closed"
    else
        return nil, "receive error"
    end
end

function WebSocketClient:listen()
    while self.connected do
        local message, err = self:receive()
        if not message and err == "closed" then
            break
        elseif not message then
            print("Receive error: " .. (err or "unknown"))
            socket.sleep(0.1) -- Brief pause before retrying
        end
    end
end

function WebSocketClient:close()
    if self.ws then
        self.ws:close()
        self.ws = nil
        self.connected = false
        print("Connection closed")
        self:on_close()
    end
end

function WebSocketClient:is_connected()
    return self.connected
end

-- Event handlers - override these in your implementation
function WebSocketClient:on_open()
    -- Override this method
end

function WebSocketClient:on_message(message)
    -- Override this method
end

function WebSocketClient:on_close(code, reason)
    -- Override this method
end

function WebSocketClient:on_error(error)
    -- Override this method
    print("WebSocket error: " .. (error or "unknown"))
end

-- Alternative implementation using lua-resty-websocket (for OpenResty/nginx)
local function create_resty_client(url)
    local resty_websocket = require("resty.websocket.client")
    
    local wb, err = resty_websocket:new({
        timeout = 5000,
        max_payload_len = 65535,
    })
    
    if not wb then
        print("Failed to create WebSocket client: " .. (err or "unknown error"))
        return nil
    end
    
    local ok, err = wb:connect(url)
    if not ok then
        print("Failed to connect: " .. (err or "unknown error"))
        return nil
    end
    
    print("Connected to WebSocket server (resty)")
    return wb
end

-- Simple WebSocket client using basic sockets (fallback)
local function create_simple_client(host, port)
    local sock = socket.tcp()
    sock:settimeout(5)
    
    local ok, err = sock:connect(host, port)
    if not ok then
        print("Failed to connect: " .. (err or "unknown error"))
        return nil
    end
    
    -- Send WebSocket handshake
    local handshake = string.format(
        "GET / HTTP/1.1\r\n" ..
        "Host: %s:%d\r\n" ..
        "Upgrade: websocket\r\n" ..
        "Connection: Upgrade\r\n" ..
        "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n" ..
        "Sec-WebSocket-Version: 13\r\n" ..
        "\r\n",
        host, port
    )
    
    sock:send(handshake)
    
    -- Read response
    local response = sock:receive("*l")
    if not response or not response:match("101 Switching Protocols") then
        print("Handshake failed")
        sock:close()
        return nil
    end
    
    -- Skip remaining headers
    repeat
        local line = sock:receive("*l")
    until line == ""
    
    print("Connected to WebSocket server (simple)")
    return sock
end

-- Usage examples
local function basic_example()
    print("=== Basic WebSocket Client Example ===")
    
    local client = WebSocketClient:new("ws://localhost:8080")
    
    -- Override event handlers
    function client:on_open()
        print("Custom: Connection opened!")
    end
    
    function client:on_message(message)
        print("Custom: Processing message: " .. message)
    end
    
    function client:on_close(code, reason)
        print("Custom: Connection closed")
    end
    
    -- Connect and send messages
    if client:connect() then
        -- Send a message
        socket.sleep(1)
        client:send("Hello from Lua!")
        
        -- Send JSON message (if JSON library is available)
        --[[
        client:send_json({
            type = "greeting",
            message = "Hello from Lua JSON!",
            timestamp = os.time()
        })
        --]]
        
        -- Listen for messages in background
        local listen_thread = coroutine.create(function()
            client:listen()
        end)
        coroutine.resume(listen_thread)
        
        -- Keep connection alive
        socket.sleep(5)
        
        -- Close connection
        client:close()
    end
    
    print("Basic example completed")
end

-- Simple send function
local function send_simple_message(url, message)
    print("Sending simple message to " .. url)
    
    local client = WebSocketClient:new(url)
    
    if client:connect() then
        socket.sleep(0.5) -- Wait for connection to stabilize
        client:send(message)
        socket.sleep(1) -- Wait for response
        client:close()
    end
end

-- Ping-pong example
local function ping_pong_example()
    print("\n=== Ping-Pong Example ===")
    
    local client = WebSocketClient:new("ws://localhost:8080")
    
    function client:on_message(message)
        print("Received: " .. message)
        if message == "ping" then
            self:send("pong")
        elseif message == "pong" then
            print("Got pong response!")
        end
    end
    
    if client:connect() then
        -- Send ping every 2 seconds
        for i = 1, 3 do
            socket.sleep(2)
            client:send("ping")
        end
        
        socket.sleep(2)
        client:close()
    end
    
    print("Ping-pong example completed")
end

-- Main execution
local function main()
    print("Lua WebSocket Client Examples")
    print("=============================")
    
    -- Check command line arguments
    local arg = arg or {}
    
    if arg[1] == "simple" then
        local message = arg[2] or "Simple message from Lua"
        send_simple_message("ws://localhost:8080", message)
    elseif arg[1] == "ping" then
        ping_pong_example()
    else
        basic_example()
    end
    
    print("\nAll examples completed!")
end

-- Export the WebSocketClient class
_G.WebSocketClient = WebSocketClient

-- Run main if this file is executed directly
if arg and arg[0] and arg[0]:match("websocket%-lua%.lua$") then
    main()
end

--[[
To run this script:

1. Install lua-websockets:
   luarocks install lua-websockets

2. Run:
   lua websocket-lua.lua
   lua websocket-lua.lua simple "Hello World"
   lua websocket-lua.lua ping

Alternative libraries you might want to use:
- lua-resty-websocket (for OpenResty/nginx)
- luasocket (for basic socket operations)
- cjson or dkjson (for JSON encoding/decoding)

Install with:
luarocks install lua-resty-websocket
luarocks install luasocket
luarocks install lua-cjson
--]]