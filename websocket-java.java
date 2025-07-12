// Java WebSocket Client
import java.net.URI;
import java.util.concurrent.CountDownLatch;
import org.java_websocket.client.WebSocketClient;
import org.java_websocket.handshake.ServerHandshake;

public class WebSocketExample {
    
    public static class CustomWebSocketClient extends WebSocketClient {
        private CountDownLatch connectionLatch = new CountDownLatch(1);
        
        public CustomWebSocketClient(URI serverUri) {
            super(serverUri);
        }
        
        @Override
        public void onOpen(ServerHandshake handshake) {
            System.out.println("Connected to WebSocket server");
            connectionLatch.countDown();
        }
        
        @Override
        public void onMessage(String message) {
            System.out.println("Received: " + message);
        }
        
        @Override
        public void onClose(int code, String reason, boolean remote) {
            System.out.println("Connection closed: " + reason);
        }
        
        @Override
        public void onError(Exception ex) {
            System.err.println("WebSocket error: " + ex.getMessage());
        }
        
        public void waitForConnection() throws InterruptedException {
            connectionLatch.await();
        }
    }
    
    public static void main(String[] args) {
        try {
            URI serverUri = new URI("ws://localhost:8080");
            CustomWebSocketClient client = new CustomWebSocketClient(serverUri);
            
            // Connect to server
            client.connect();
            client.waitForConnection();
            
            // Send a message
            client.send("Hello from Java!");
            
            // Keep connection alive
            Thread.sleep(5000);
            
            // Close connection
            client.close();
            
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}