-- Haskell WebSocket Client
{-# LANGUAGE OverloadedStrings #-}

import Network.WebSockets
import Control.Concurrent (forkIO, threadDelay)
import Control.Monad (forever, void)
import Control.Exception (finally)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as T

-- WebSocket Client data type
data WebSocketClient = WebSocketClient
    { wsConnection :: Connection
    , wsUrl :: String
    }

-- Create a new WebSocket client
newWebSocketClient :: String -> IO (Maybe WebSocketClient)
newWebSocketClient url = do
    putStrLn $ "Connecting to " ++ url
    
    -- Parse the URL (simplified for localhost)
    let host = "localhost"
        port = 8080
        path = "/"
    
    -- Connect to WebSocket server
    runClient host port path $ \conn -> do
        putStrLn "Connected to WebSocket server"
        
        let client = WebSocketClient conn url
        
        -- Start message listener in separate thread
        _ <- forkIO $ messageListener client
        
        -- Send initial message
        threadDelay 1000000  -- Wait 1 second
        sendMessage client "Hello from Haskell!"
        
        -- Keep connection alive
        threadDelay 5000000  -- Wait 5 seconds
        
        putStrLn "Closing connection"
        return ()

-- Send a message through WebSocket
sendMessage :: WebSocketClient -> Text -> IO ()
sendMessage client message = do
    sendTextData (wsConnection client) message
    T.putStrLn $ "Sent: " <> message

-- Listen for incoming messages
messageListener :: WebSocketClient -> IO ()
messageListener client = forever $ do
    message <- receiveData (wsConnection client)
    T.putStrLn $ "Received: " <> message
    onMessage client message

-- Handle incoming messages (override this in your implementation)
onMessage :: WebSocketClient -> Text -> IO ()
onMessage _ message = do
    -- Default message handler
    T.putStrLn $ "Processing message: " <> message

-- Send JSON message
sendJsonMessage :: WebSocketClient -> Text -> Text -> IO ()
sendJsonMessage client msgType content = do
    let jsonMsg = "{\"type\":\"" <> msgType <> "\",\"data\":\"" <> content <> "\"}"
    sendMessage client jsonMsg

-- WebSocket client with custom handlers
data WebSocketHandlers = WebSocketHandlers
    { onOpen :: IO ()
    , onMessageReceived :: Text -> IO ()
    , onClose :: IO ()
    , onError :: String -> IO ()
    }

-- Default handlers
defaultHandlers :: WebSocketHandlers
defaultHandlers = WebSocketHandlers
    { onOpen = putStrLn "WebSocket opened"
    , onMessageReceived = T.putStrLn . ("Received: " <>)
    , onClose = putStrLn "WebSocket closed"
    , onError = putStrLn . ("WebSocket error: " <>)
    }

-- Run WebSocket client with custom handlers
runWebSocketClient :: String -> WebSocketHandlers -> IO ()
runWebSocketClient url handlers = do
    putStrLn $ "Connecting to " ++ url
    
    let host = "localhost"
        port = 8080
        path = "/"
    
    runClient host port path $ \conn -> do
        onOpen handlers
        
        -- Start message listener
        _ <- forkIO $ forever $ do
            message <- receiveData conn
            onMessageReceived handlers message
        
        -- Send a test message
        threadDelay 1000000
        sendTextData conn ("Hello from Haskell!" :: Text)
        T.putStrLn "Sent: Hello from Haskell!"
        
        -- Keep alive
        threadDelay 5000000
        
        onClose handlers
    `finally` onClose handlers

-- Example usage with custom handlers
exampleWithHandlers :: IO ()
exampleWithHandlers = do
    let customHandlers = WebSocketHandlers
            { onOpen = putStrLn "Custom: Connected to server!"
            , onMessageReceived = \msg -> T.putStrLn $ "Custom: Got message: " <> msg
            , onClose = putStrLn "Custom: Connection closed!"
            , onError = \err -> putStrLn $ "Custom: Error occurred: " <> err
            }
    
    runWebSocketClient "ws://localhost:8080" customHandlers

-- Simple ping-pong example
pingPongClient :: IO ()
pingPongClient = do
    putStrLn "Starting ping-pong client"
    
    runClient "localhost" 8080 "/" $ \conn -> do
        putStrLn "Connected for ping-pong"
        
        -- Send ping every 2 seconds
        _ <- forkIO $ forever $ do
            threadDelay 2000000
            sendTextData conn ("ping" :: Text)
            putStrLn "Sent: ping"
        
        -- Listen for pongs
        forever $ do
            message <- receiveData conn
            T.putStrLn $ "Received: " <> message
            
            if message == "pong"
                then putStrLn "Got pong response!"
                else T.putStrLn $ "Unexpected message: " <> message

-- Main function
main :: IO ()
main = do
    putStrLn "Haskell WebSocket Client Examples"
    putStrLn "================================"
    
    putStrLn "\n1. Basic client:"
    result <- newWebSocketClient "ws://localhost:8080"
    case result of
        Just _ -> putStrLn "Basic client completed successfully"
        Nothing -> putStrLn "Basic client failed to connect"
    
    putStrLn "\n2. Client with custom handlers:"
    exampleWithHandlers
    
    putStrLn "\nAll examples completed"

{-
To compile and run:

1. Install dependencies:
   cabal install websockets text

2. Compile:
   ghc -o websocket_client websocket-haskell.hs

3. Run:
   ./websocket_client

Or use cabal:

1. Create websocket-client.cabal:
   name: websocket-client
   version: 0.1.0.0
   build-type: Simple
   cabal-version: >=1.10
   
   executable websocket-client
     main-is: websocket-haskell.hs
     build-depends: base >=4.7 && <5,
                    websockets,
                    text
     default-language: Haskell2010

2. Run:
   cabal run
-}