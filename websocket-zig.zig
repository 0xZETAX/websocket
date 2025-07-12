// Zig WebSocket Client
const std = @import("std");
const net = std.net;
const print = std.debug.print;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const WebSocketError = error{
    ConnectionFailed,
    HandshakeFailed,
    SendFailed,
    ReceiveFailed,
    InvalidFrame,
};

const WebSocketClient = struct {
    allocator: Allocator,
    stream: net.Stream,
    connected: bool,
    url: []const u8,

    const Self = @This();

    pub fn init(allocator: Allocator, url: []const u8) Self {
        return Self{
            .allocator = allocator,
            .stream = undefined,
            .connected = false,
            .url = url,
        };
    }

    pub fn connect(self: *Self) !void {
        // Parse URL (simplified for localhost)
        const host = "127.0.0.1";
        const port: u16 = 8080;

        print("Connecting to {s}:{d}\n", .{ host, port });

        // Create socket connection
        const address = try net.Address.parseIp(host, port);
        self.stream = try net.tcpConnectToAddress(address);

        // Send WebSocket handshake
        try self.sendHandshake();

        // Receive and validate handshake response
        try self.receiveHandshake();

        self.connected = true;
        print("Connected to WebSocket server\n");
        self.onOpen();
    }

    fn sendHandshake(self: *Self) !void {
        const handshake =
            "GET / HTTP/1.1\r\n" ++
            "Host: localhost:8080\r\n" ++
            "Upgrade: websocket\r\n" ++
            "Connection: Upgrade\r\n" ++
            "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n" ++
            "Sec-WebSocket-Version: 13\r\n" ++
            "\r\n";

        _ = try self.stream.writeAll(handshake);
    }

    fn receiveHandshake(self: *Self) !void {
        var buffer: [1024]u8 = undefined;
        const bytes_read = try self.stream.readAll(buffer[0..]);

        if (bytes_read == 0) {
            return WebSocketError.HandshakeFailed;
        }

        const response = buffer[0..bytes_read];
        if (std.mem.indexOf(u8, response, "101 Switching Protocols") == null) {
            return WebSocketError.HandshakeFailed;
        }

        print("Handshake successful\n");
    }

    pub fn send(self: *Self, message: []const u8) !void {
        if (!self.connected) {
            print("Not connected, cannot send message\n");
            return;
        }

        // Create WebSocket frame
        var frame = ArrayList(u8).init(self.allocator);
        defer frame.deinit();

        // Frame format: FIN(1) + RSV(3) + Opcode(4) = 0x81 for text frame
        try frame.append(0x81);

        // Payload length
        if (message.len < 126) {
            try frame.append(@intCast(u8, message.len | 0x80)); // Set mask bit
        } else if (message.len < 65536) {
            try frame.append(126 | 0x80);
            try frame.append(@intCast(u8, (message.len >> 8) & 0xFF));
            try frame.append(@intCast(u8, message.len & 0xFF));
        } else {
            // For simplicity, not handling large payloads
            return WebSocketError.SendFailed;
        }

        // Masking key (4 bytes)
        const mask_key = [4]u8{ 0x12, 0x34, 0x56, 0x78 };
        try frame.appendSlice(&mask_key);

        // Masked payload
        for (message) |byte, i| {
            try frame.append(byte ^ mask_key[i % 4]);
        }

        // Send frame
        _ = try self.stream.writeAll(frame.items);
        print("Sent: {s}\n", .{message});
    }

    pub fn receive(self: *Self) ![]u8 {
        if (!self.connected) {
            return WebSocketError.ReceiveFailed;
        }

        var header: [2]u8 = undefined;
        _ = try self.stream.readAll(header[0..]);

        const fin = (header[0] & 0x80) != 0;
        const opcode = header[0] & 0x0F;
        const masked = (header[1] & 0x80) != 0;
        var payload_len = header[1] & 0x7F;

        // Handle extended payload length
        if (payload_len == 126) {
            var len_bytes: [2]u8 = undefined;
            _ = try self.stream.readAll(len_bytes[0..]);
            payload_len = (@intCast(u64, len_bytes[0]) << 8) | len_bytes[1];
        } else if (payload_len == 127) {
            // For simplicity, not handling very large payloads
            return WebSocketError.InvalidFrame;
        }

        // Read mask key if present
        var mask_key: [4]u8 = undefined;
        if (masked) {
            _ = try self.stream.readAll(mask_key[0..]);
        }

        // Read payload
        const payload = try self.allocator.alloc(u8, payload_len);
        _ = try self.stream.readAll(payload);

        // Unmask payload if needed
        if (masked) {
            for (payload) |*byte, i| {
                byte.* ^= mask_key[i % 4];
            }
        }

        // Handle different frame types
        switch (opcode) {
            0x1 => { // Text frame
                print("Received: {s}\n", .{payload});
                self.onMessage(payload);
                return payload;
            },
            0x8 => { // Close frame
                print("Received close frame\n");
                self.connected = false;
                self.onClose();
                return payload;
            },
            0x9 => { // Ping frame
                print("Received ping\n");
                try self.sendPong(payload);
                return payload;
            },
            0xA => { // Pong frame
                print("Received pong\n");
                return payload;
            },
            else => {
                print("Received unknown frame type: {d}\n", .{opcode});
                return payload;
            },
        }
    }

    fn sendPong(self: *Self, data: []const u8) !void {
        var frame = ArrayList(u8).init(self.allocator);
        defer frame.deinit();

        try frame.append(0x8A); // Pong frame
        try frame.append(@intCast(u8, data.len | 0x80)); // Set mask bit

        // Masking key
        const mask_key = [4]u8{ 0x12, 0x34, 0x56, 0x78 };
        try frame.appendSlice(&mask_key);

        // Masked payload
        for (data) |byte, i| {
            try frame.append(byte ^ mask_key[i % 4]);
        }

        _ = try self.stream.writeAll(frame.items);
        print("Sent pong\n");
    }

    pub fn listen(self: *Self) !void {
        while (self.connected) {
            const message = self.receive() catch |err| {
                print("Error receiving message: {}\n", .{err});
                break;
            };
            self.allocator.free(message);
        }
    }

    pub fn close(self: *Self) void {
        if (self.connected) {
            // Send close frame
            const close_frame = [_]u8{ 0x88, 0x80, 0x12, 0x34, 0x56, 0x78 };
            _ = self.stream.writeAll(&close_frame) catch {};

            self.stream.close();
            self.connected = false;
            print("Connection closed\n");
            self.onClose();
        }
    }

    // Event handlers - override these in your implementation
    fn onOpen(self: *Self) void {
        _ = self;
        // Override this method
    }

    fn onMessage(self: *Self, message: []const u8) void {
        _ = self;
        _ = message;
        // Override this method
    }

    fn onClose(self: *Self) void {
        _ = self;
        // Override this method
    }

    fn onError(self: *Self, err: anyerror) void {
        _ = self;
        print("WebSocket error: {}\n", .{err});
    }
};

// Usage example
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = WebSocketClient.init(allocator, "ws://localhost:8080");

    // Connect to server
    client.connect() catch |err| {
        print("Failed to connect: {}\n", .{err});
        return;
    };

    // Send a message
    std.time.sleep(1000000000); // Sleep 1 second
    try client.send("Hello from Zig!");

    // Send JSON-like message
    try client.send("{\"type\":\"greeting\",\"message\":\"Hello from Zig JSON!\"}");

    // Listen for messages in a separate thread (simplified)
    var listen_thread = try std.Thread.spawn(.{}, listenThread, .{&client});

    // Keep connection alive
    std.time.sleep(5000000000); // Sleep 5 seconds

    // Close connection
    client.close();
    listen_thread.join();

    print("WebSocket client finished\n");
}

fn listenThread(client: *WebSocketClient) void {
    client.listen() catch |err| {
        print("Listen thread error: {}\n", .{err});
    };
}

// Simple send function
pub fn sendSimpleMessage(allocator: Allocator, url: []const u8, message: []const u8) !void {
    print("Sending simple message to {s}\n", .{url});

    var client = WebSocketClient.init(allocator, url);
    try client.connect();

    std.time.sleep(500000000); // Wait 0.5 seconds
    try client.send(message);

    std.time.sleep(1000000000); // Wait 1 second
    client.close();
}

// Test function
test "WebSocket client basic functionality" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = WebSocketClient.init(allocator, "ws://localhost:8080");
    try testing.expect(!client.connected);
    try testing.expect(std.mem.eql(u8, client.url, "ws://localhost:8080"));
}

// To compile and run:
// zig build-exe websocket-zig.zig
// ./websocket-zig
//
// Or run directly:
// zig run websocket-zig.zig