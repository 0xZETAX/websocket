// Rust WebSocket Client
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message};
use futures_util::{SinkExt, StreamExt};
use url::Url;
use std::time::Duration;
use tokio::time::sleep;

pub struct WebSocketClient {
    url: String,
}

impl WebSocketClient {
    pub fn new(url: &str) -> Self {
        Self {
            url: url.to_string(),
        }
    }

    pub async fn connect(&self) -> Result<(), Box<dyn std::error::Error>> {
        let url = Url::parse(&self.url)?;
        
        println!("Connecting to {}", url);
        let (ws_stream, _) = connect_async(url).await?;
        println!("Connected to WebSocket server");

        let (mut write, mut read) = ws_stream.split();

        // Spawn a task to handle incoming messages
        let read_task = tokio::spawn(async move {
            while let Some(msg) = read.next().await {
                match msg {
                    Ok(Message::Text(text)) => {
                        println!("Received: {}", text);
                    }
                    Ok(Message::Binary(bin)) => {
                        println!("Received binary data: {} bytes", bin.len());
                    }
                    Ok(Message::Close(_)) => {
                        println!("Connection closed by server");
                        break;
                    }
                    Err(e) => {
                        println!("Error receiving message: {}", e);
                        break;
                    }
                    _ => {}
                }
            }
        });

        // Send a message
        sleep(Duration::from_secs(1)).await;
        let message = Message::Text("Hello from Rust!".to_string());
        write.send(message).await?;
        println!("Sent: Hello from Rust!");

        // Keep connection alive for a while
        sleep(Duration::from_secs(5)).await;

        // Close connection
        write.send(Message::Close(None)).await?;
        
        // Wait for read task to complete
        read_task.await?;

        Ok(())
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let client = WebSocketClient::new("ws://localhost:8080");
    
    match client.connect().await {
        Ok(_) => println!("WebSocket client finished successfully"),
        Err(e) => println!("Error: {}", e),
    }

    Ok(())
}

// Add to Cargo.toml:
/*
[dependencies]
tokio = { version = "1.0", features = ["full"] }
tokio-tungstenite = "0.20"
futures-util = "0.3"
url = "2.0"
*/