// TypeScript WebSocket Client
interface WebSocketMessage {
    type: string;
    data: any;
    timestamp: number;
}

interface WebSocketClientOptions {
    reconnectInterval?: number;
    maxReconnectAttempts?: number;
    protocols?: string[];
}

class WebSocketClient {
    private ws: WebSocket | null = null;
    private url: string;
    private options: WebSocketClientOptions;
    private reconnectAttempts: number = 0;
    private isConnected: boolean = false;

    constructor(url: string, options: WebSocketClientOptions = {}) {
        this.url = url;
        this.options = {
            reconnectInterval: 5000,
            maxReconnectAttempts: 5,
            ...options
        };
    }

    public connect(): Promise<void> {
        return new Promise((resolve, reject) => {
            try {
                this.ws = new WebSocket(this.url, this.options.protocols);

                this.ws.onopen = (event: Event) => {
                    console.log('Connected to WebSocket server');
                    this.isConnected = true;
                    this.reconnectAttempts = 0;
                    this.onOpen(event);
                    resolve();
                };

                this.ws.onmessage = (event: MessageEvent) => {
                    try {
                        const message: WebSocketMessage = JSON.parse(event.data);
                        console.log('Received:', message);
                        this.onMessage(message);
                    } catch (error) {
                        console.log('Received (raw):', event.data);
                        this.onMessage({ type: 'raw', data: event.data, timestamp: Date.now() });
                    }
                };

                this.ws.onclose = (event: CloseEvent) => {
                    console.log('Disconnected from WebSocket server');
                    this.isConnected = false;
                    this.onClose(event);
                    this.handleReconnect();
                };

                this.ws.onerror = (event: Event) => {
                    console.error('WebSocket error:', event);
                    this.onError(event);
                    reject(new Error('WebSocket connection failed'));
                };

            } catch (error) {
                reject(error);
            }
        });
    }

    public send(message: WebSocketMessage | string): void {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            const data = typeof message === 'string' 
                ? message 
                : JSON.stringify(message);
            this.ws.send(data);
            console.log('Sent:', data);
        } else {
            console.warn('WebSocket is not connected');
        }
    }

    public close(): void {
        if (this.ws) {
            this.ws.close();
            this.ws = null;
        }
    }

    private handleReconnect(): void {
        if (this.reconnectAttempts < (this.options.maxReconnectAttempts || 5)) {
            this.reconnectAttempts++;
            console.log(`Attempting to reconnect... (${this.reconnectAttempts})`);
            
            setTimeout(() => {
                this.connect().catch(error => {
                    console.error('Reconnection failed:', error);
                });
            }, this.options.reconnectInterval);
        } else {
            console.error('Max reconnection attempts reached');
        }
    }

    // Event handlers - override these in your implementation
    protected onOpen(event: Event): void {}
    protected onMessage(message: WebSocketMessage): void {}
    protected onClose(event: CloseEvent): void {}
    protected onError(event: Event): void {}

    // Getters
    public get connected(): boolean {
        return this.isConnected;
    }

    public get readyState(): number {
        return this.ws ? this.ws.readyState : WebSocket.CLOSED;
    }
}

// Usage example
const client = new WebSocketClient('ws://localhost:8080', {
    reconnectInterval: 3000,
    maxReconnectAttempts: 3
});

client.connect().then(() => {
    // Send a message after connection
    setTimeout(() => {
        client.send({
            type: 'greeting',
            data: 'Hello from TypeScript!',
            timestamp: Date.now()
        });
    }, 1000);
}).catch(error => {
    console.error('Failed to connect:', error);
});

export { WebSocketClient, WebSocketMessage, WebSocketClientOptions };