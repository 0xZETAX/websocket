// F# WebSocket Client
open System
open System.Net.WebSockets
open System.Text
open System.Threading
open System.Threading.Tasks
open System.IO

type WebSocketClient(uri: string) =
    let mutable webSocket: ClientWebSocket option = None
    let mutable cancellationTokenSource = new CancellationTokenSource()
    let mutable isConnected = false

    // Event-like members using F# events
    let openEvent = Event<unit>()
    let messageEvent = Event<string>()
    let closeEvent = Event<unit>()
    let errorEvent = Event<exn>()

    // Public events
    member _.OnOpen = openEvent.Publish
    member _.OnMessage = messageEvent.Publish
    member _.OnClose = closeEvent.Publish
    member _.OnError = errorEvent.Publish

    // Connect to WebSocket server
    member this.ConnectAsync() =
        async {
            try
                printfn "Connecting to %s" uri
                let ws = new ClientWebSocket()
                webSocket <- Some ws
                
                do! ws.ConnectAsync(Uri(uri), cancellationTokenSource.Token) |> Async.AwaitTask
                
                isConnected <- true
                printfn "Connected to WebSocket server"
                openEvent.Trigger()
                
                // Start listening for messages
                this.StartListening() |> ignore
                
            with
            | ex ->
                printfn "Connection error: %s" ex.Message
                errorEvent.Trigger(ex)
        }

    // Start listening for messages in background
    member private this.StartListening() =
        async {
            let buffer = Array.zeroCreate<byte> (1024 * 4)
            
            try
                while isConnected && webSocket.IsSome do
                    let ws = webSocket.Value
                    let! result = ws.ReceiveAsync(ArraySegment<byte>(buffer), cancellationTokenSource.Token) |> Async.AwaitTask
                    
                    match result.MessageType with
                    | WebSocketMessageType.Text ->
                        let message = Encoding.UTF8.GetString(buffer, 0, result.Count)
                        printfn "Received: %s" message
                        messageEvent.Trigger(message)
                        
                    | WebSocketMessageType.Close ->
                        printfn "Connection closed by server"
                        isConnected <- false
                        closeEvent.Trigger()
                        
                    | WebSocketMessageType.Binary ->
                        printfn "Received binary data: %d bytes" result.Count
                        
                    | _ -> ()
                        
            with
            | ex when not (ex :? OperationCanceledException) ->
                printfn "Listen error: %s" ex.Message
                errorEvent.Trigger(ex)
        } |> Async.Start

    // Send a text message
    member this.SendAsync(message: string) =
        async {
            if isConnected && webSocket.IsSome then
                try
                    let ws = webSocket.Value
                    let buffer = Encoding.UTF8.GetBytes(message)
                    do! ws.SendAsync(ArraySegment<byte>(buffer), WebSocketMessageType.Text, true, cancellationTokenSource.Token) |> Async.AwaitTask
                    printfn "Sent: %s" message
                with
                | ex ->
                    printfn "Send error: %s" ex.Message
                    errorEvent.Trigger(ex)
            else
                printfn "Not connected, cannot send message"
        }

    // Send JSON message
    member this.SendJsonAsync(data: obj) =
        async {
            let json = System.Text.Json.JsonSerializer.Serialize(data)
            do! this.SendAsync(json)
        }

    // Close the connection
    member this.CloseAsync() =
        async {
            if isConnected && webSocket.IsSome then
                try
                    let ws = webSocket.Value
                    do! ws.CloseAsync(WebSocketCloseStatus.NormalClosure, "", cancellationTokenSource.Token) |> Async.AwaitTask
                    isConnected <- false
                    closeEvent.Trigger()
                with
                | ex ->
                    printfn "Close error: %s" ex.Message
                    errorEvent.Trigger(ex)
        }

    // Properties
    member _.IsConnected = isConnected
    member _.ReadyState = 
        match webSocket with
        | Some ws -> ws.State
        | None -> WebSocketState.None

    // IDisposable implementation
    interface IDisposable with
        member this.Dispose() =
            cancellationTokenSource.Cancel()
            match webSocket with
            | Some ws -> ws.Dispose()
            | None -> ()
            cancellationTokenSource.Dispose()

// Custom WebSocket client with event handlers
type CustomWebSocketClient(uri: string) =
    inherit WebSocketClient(uri)
    
    do
        // Subscribe to events in constructor
        base.OnOpen.Add(fun () -> printfn "Custom: WebSocket connection opened!")
        base.OnMessage.Add(fun message -> 
            printfn "Custom: Processing message: %s" message
            // Echo the message back
            if base.IsConnected then
                let response = sprintf "Echo: %s" message
                base.SendAsync(response) |> Async.Start
        )
        base.OnClose.Add(fun () -> printfn "Custom: Connection closed")
        base.OnError.Add(fun ex -> printfn "Custom: Error occurred: %s" ex.Message)

// Usage examples
module Examples =
    
    // Basic example
    let basicExample() =
        async {
            printfn "=== Basic WebSocket Client Example ==="
            
            use client = new WebSocketClient("ws://localhost:8080")
            
            // Subscribe to events
            client.OnOpen.Add(fun () -> printfn "Event: Connection opened!")
            client.OnMessage.Add(fun message -> printfn "Event: Received message: %s" message)
            client.OnClose.Add(fun () -> printfn "Event: Connection closed!")
            client.OnError.Add(fun ex -> printfn "Event: Error: %s" ex.Message)
            
            // Connect to server
            do! client.ConnectAsync()
            
            // Wait a moment for connection
            do! Async.Sleep(1000)
            
            // Send messages
            do! client.SendAsync("Hello from F#!")
            
            // Send JSON message
            let jsonData = {| 
                Type = "greeting"
                Message = "Hello from F# JSON!"
                Timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds()
            |}
            do! client.SendJsonAsync(jsonData)
            
            // Keep connection alive
            do! Async.Sleep(5000)
            
            // Close connection
            do! client.CloseAsync()
            
            printfn "Basic example completed"
        }

    // Custom client example
    let customExample() =
        async {
            printfn "\n=== Custom WebSocket Client Example ==="
            
            use client = new CustomWebSocketClient("ws://localhost:8080")
            
            do! client.ConnectAsync()
            do! Async.Sleep(1000)
            
            do! client.SendAsync("Test message for custom client")
            
            do! Async.Sleep(3000)
            do! client.CloseAsync()
            
            printfn "Custom example completed"
        }

    // Ping-pong example
    let pingPongExample() =
        async {
            printfn "\n=== Ping-Pong Example ==="
            
            use client = new WebSocketClient("ws://localhost:8080")
            
            // Handle ping-pong messages
            client.OnMessage.Add(fun message ->
                match message with
                | "ping" -> 
                    printfn "Received ping, sending pong"
                    client.SendAsync("pong") |> Async.Start
                | "pong" -> 
                    printfn "Got pong response!"
                | _ -> 
                    printfn "Unexpected message: %s" message
            )
            
            do! client.ConnectAsync()
            do! Async.Sleep(1000)
            
            // Send ping every 2 seconds
            for i in 1..3 do
                do! client.SendAsync("ping")
                do! Async.Sleep(2000)
            
            do! client.CloseAsync()
            printfn "Ping-pong example completed"
        }

// Simple send function
let sendSimpleMessage (url: string) (message: string) =
    async {
        printfn "Sending simple message to %s" url
        
        use client = new WebSocketClient(url)
        do! client.ConnectAsync()
        do! Async.Sleep(500)
        do! client.SendAsync(message)
        do! Async.Sleep(1000)
        do! client.CloseAsync()
    }

// Main execution
[<EntryPoint>]
let main args =
    async {
        printfn "F# WebSocket Client Examples"
        printfn "============================"
        
        try
            match args with
            | [| "basic" |] -> 
                do! Examples.basicExample()
            | [| "custom" |] -> 
                do! Examples.customExample()
            | [| "ping" |] -> 
                do! Examples.pingPongExample()
            | [| "simple"; message |] -> 
                do! sendSimpleMessage "ws://localhost:8080" message
            | [| "simple" |] -> 
                do! sendSimpleMessage "ws://localhost:8080" "Simple message from F#"
            | _ ->
                do! Examples.basicExample()
                do! Examples.customExample()
                do! Examples.pingPongExample()
                
            printfn "\nAll examples completed successfully!"
            
        with
        | ex -> printfn "Error: %s" ex.Message
        
        return 0
    } |> Async.RunSynchronously

(*
To compile and run:

1. Create a project file (websocket-client.fsproj):
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net6.0</TargetFramework>
  </PropertyGroup>
  <ItemGroup>
    <Compile Include="websocket-fsharp.fs" />
  </ItemGroup>
</Project>

2. Build and run:
dotnet build
dotnet run
dotnet run basic
dotnet run custom
dotnet run ping
dotnet run simple "Hello World"

Or compile directly:
fsharpc websocket-fsharp.fs
mono websocket-fsharp.exe
*)