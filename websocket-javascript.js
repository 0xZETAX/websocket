// JavaScript WebSocket Client
const WebSocket = require('ws');

class WebSocketClient {
    constructor(url) {
        this.url = url;
        this.ws = null;
    }

    connect() {
        this.ws = new WebSocket(this.url);

        this.ws.on('open', () => {
            console.log('Connected to WebSocket server');
            this.onOpen();
        });

        this.ws.on('message', (data) => {
            console.log('Received:', data.toString());
            this.onMessage(data.toString());
        });

        this.ws.on('close', () => {
            console.log('Disconnected from WebSocket server');
            this.onClose();
        });

        this.ws.on('error', (error) => {
            console.error('WebSocket error:', error);
            this.onError(error);
        });
    }

    send(message) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(message);
        }
    }

    close() {
        if (this.ws) {
            this.ws.close();
        }
    }

    // Override these methods in your implementation
    onOpen() {}
    onMessage(message) {}
    onClose() {}
    onError(error) {}
}

// Usage example
const client = new WebSocketClient('ws://localhost:8080');
client.connect();

// Send a message after connection
setTimeout(() => {
    client.send('Hello from JavaScript!');
}, 1000);