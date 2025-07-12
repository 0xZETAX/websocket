// Go WebSocket Client
package main

import (
    "fmt"
    "log"
    "net/url"
    "os"
    "os/signal"
    "time"

    "github.com/gorilla/websocket"
)

type WebSocketClient struct {
    conn   *websocket.Conn
    url    string
    done   chan struct{}
}

func NewWebSocketClient(urlStr string) *WebSocketClient {
    return &WebSocketClient{
        url:  urlStr,
        done: make(chan struct{}),
    }
}

func (c *WebSocketClient) Connect() error {
    u, err := url.Parse(c.url)
    if err != nil {
        return err
    }

    conn, _, err := websocket.DefaultDialer.Dial(u.String(), nil)
    if err != nil {
        return err
    }

    c.conn = conn
    fmt.Println("Connected to WebSocket server")

    // Start listening for messages
    go c.listen()

    return nil
}

func (c *WebSocketClient) listen() {
    defer close(c.done)
    for {
        _, message, err := c.conn.ReadMessage()
        if err != nil {
            log.Println("Read error:", err)
            return
        }
        fmt.Printf("Received: %s\n", message)
    }
}

func (c *WebSocketClient) Send(message string) error {
    if c.conn == nil {
        return fmt.Errorf("not connected")
    }
    
    err := c.conn.WriteMessage(websocket.TextMessage, []byte(message))
    if err != nil {
        return err
    }
    
    fmt.Printf("Sent: %s\n", message)
    return nil
}

func (c *WebSocketClient) Close() error {
    if c.conn != nil {
        return c.conn.Close()
    }
    return nil
}

func main() {
    client := NewWebSocketClient("ws://localhost:8080")

    // Handle interrupt signal
    interrupt := make(chan os.Signal, 1)
    signal.Notify(interrupt, os.Interrupt)

    // Connect to server
    err := client.Connect()
    if err != nil {
        log.Fatal("Connection error:", err)
    }
    defer client.Close()

    // Send a message
    time.Sleep(1 * time.Second)
    client.Send("Hello from Go!")

    // Wait for interrupt or done
    select {
    case <-client.done:
        fmt.Println("Connection closed")
    case <-interrupt:
        fmt.Println("Interrupt received, closing connection")
    }
}