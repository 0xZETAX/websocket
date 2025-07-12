// C# WebSocket Client
using System;
using System.Net.WebSockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

public class WebSocketClient
{
    private ClientWebSocket webSocket;
    private CancellationTokenSource cancellationTokenSource;
    private string uri;

    public WebSocketClient(string uri)
    {
        this.uri = uri;
        this.webSocket = new ClientWebSocket();
        this.cancellationTokenSource = new CancellationTokenSource();
    }

    public async Task ConnectAsync()
    {
        try
        {
            await webSocket.ConnectAsync(new Uri(uri), cancellationTokenSource.Token);
            Console.WriteLine("Connected to WebSocket server");
            
            // Start listening for messages
            _ = Task.Run(ListenAsync);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Connection error: {ex.Message}");
        }
    }

    private async Task ListenAsync()
    {
        var buffer = new byte[1024 * 4];
        
        try
        {
            while (webSocket.State == WebSocketState.Open)
            {
                var result = await webSocket.ReceiveAsync(
                    new ArraySegment<byte>(buffer), 
                    cancellationTokenSource.Token
                );

                if (result.MessageType == WebSocketMessageType.Text)
                {
                    var message = Encoding.UTF8.GetString(buffer, 0, result.Count);
                    Console.WriteLine($"Received: {message}");
                    OnMessage(message);
                }
                else if (result.MessageType == WebSocketMessageType.Close)
                {
                    await webSocket.CloseAsync(
                        WebSocketCloseStatus.NormalClosure, 
                        "", 
                        cancellationTokenSource.Token
                    );
                    Console.WriteLine("Connection closed");
                    OnClose();
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Listen error: {ex.Message}");
        }
    }

    public async Task SendAsync(string message)
    {
        if (webSocket.State == WebSocketState.Open)
        {
            var buffer = Encoding.UTF8.GetBytes(message);
            await webSocket.SendAsync(
                new ArraySegment<byte>(buffer), 
                WebSocketMessageType.Text, 
                true, 
                cancellationTokenSource.Token
            );
            Console.WriteLine($"Sent: {message}");
        }
    }

    public async Task CloseAsync()
    {
        if (webSocket.State == WebSocketState.Open)
        {
            await webSocket.CloseAsync(
                WebSocketCloseStatus.NormalClosure, 
                "", 
                cancellationTokenSource.Token
            );
        }
        webSocket.Dispose();
        cancellationTokenSource.Cancel();
    }

    // Override these methods in your implementation
    protected virtual void OnMessage(string message) { }
    protected virtual void OnClose() { }
}

// Usage example
class Program
{
    static async Task Main(string[] args)
    {
        var client = new WebSocketClient("ws://localhost:8080");
        
        await client.ConnectAsync();
        
        // Send a message
        await Task.Delay(1000);
        await client.SendAsync("Hello from C#!");
        
        // Keep connection alive
        await Task.Delay(5000);
        
        await client.CloseAsync();
    }
}