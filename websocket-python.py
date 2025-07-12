# Python WebSocket Client
import asyncio
import websockets
import json

class WebSocketClient:
    def __init__(self, uri):
        self.uri = uri
        self.websocket = None

    async def connect(self):
        """Connect to WebSocket server"""
        try:
            self.websocket = await websockets.connect(self.uri)
            print(f"Connected to {self.uri}")
            await self.listen()
        except Exception as e:
            print(f"Connection error: {e}")

    async def listen(self):
        """Listen for incoming messages"""
        try:
            async for message in self.websocket:
                await self.on_message(message)
        except websockets.exceptions.ConnectionClosed:
            print("Connection closed")
        except Exception as e:
            print(f"Error: {e}")

    async def send(self, message):
        """Send message to server"""
        if self.websocket:
            await self.websocket.send(message)
            print(f"Sent: {message}")

    async def close(self):
        """Close connection"""
        if self.websocket:
            await self.websocket.close()

    async def on_message(self, message):
        """Handle incoming message"""
        print(f"Received: {message}")

# Usage example
async def main():
    client = WebSocketClient("ws://localhost:8080")
    
    # Connect and send a message
    await client.connect()
    await client.send("Hello from Python!")
    
    # Keep connection alive
    await asyncio.sleep(5)
    await client.close()

if __name__ == "__main__":
    asyncio.run(main())