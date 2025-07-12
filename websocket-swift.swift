// Swift WebSocket Client
import Foundation
import Network

@available(macOS 10.14, iOS 12.0, *)
class WebSocketClient {
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    func connect() {
        let urlSession = URLSession(configuration: .default)
        self.urlSession = urlSession
        
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        
        print("Connected to WebSocket server")
        
        // Start listening for messages
        listen()
    }
    
    private func listen() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    print("Received: \(text)")
                    self?.onMessage(text)
                case .data(let data):
                    print("Received binary data: \(data.count) bytes")
                    self?.onBinaryMessage(data)
                @unknown default:
                    break
                }
                
                // Continue listening
                self?.listen()
                
            case .failure(let error):
                print("WebSocket error: \(error)")
                self?.onError(error)
            }
        }
    }
    
    func send(_ message: String) {
        let message = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("Send error: \(error)")
            } else {
                print("Sent: \(message)")
            }
        }
    }
    
    func send(_ data: Data) {
        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("Send error: \(error)")
            } else {
                print("Sent binary data: \(data.count) bytes")
            }
        }
    }
    
    func close() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        urlSession?.invalidateAndCancel()
    }
    
    // Override these methods in your implementation
    func onMessage(_ message: String) {
        // Handle incoming text message
    }
    
    func onBinaryMessage(_ data: Data) {
        // Handle incoming binary message
    }
    
    func onError(_ error: Error) {
        // Handle error
    }
}

// Usage example
@available(macOS 10.14, iOS 12.0, *)
class WebSocketExample {
    static func run() {
        guard let url = URL(string: "ws://localhost:8080") else {
            print("Invalid URL")
            return
        }
        
        let client = WebSocketClient(url: url)
        client.connect()
        
        // Send a message after connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            client.send("Hello from Swift!")
        }
        
        // Keep connection alive
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            client.close()
        }
    }
}

// Run the example
if #available(macOS 10.14, iOS 12.0, *) {
    WebSocketExample.run()
    
    // Keep the program running
    RunLoop.main.run()
}