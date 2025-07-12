// Kotlin WebSocket Client
import okhttp3.*
import okio.ByteString
import java.util.concurrent.TimeUnit

class WebSocketClient(private val url: String) {
    private var webSocket: WebSocket? = null
    private val client = OkHttpClient.Builder()
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    private val listener = object : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) {
            println("Connected to WebSocket server")
            onConnectionOpen(webSocket, response)
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            println("Received: $text")
            onTextMessage(text)
        }

        override fun onMessage(webSocket: WebSocket, bytes: ByteString) {
            println("Received binary data: ${bytes.size} bytes")
            onBinaryMessage(bytes)
        }

        override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
            println("Connection closing: $code $reason")
            onConnectionClosing(code, reason)
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            println("Connection closed: $code $reason")
            onConnectionClosed(code, reason)
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            println("WebSocket error: ${t.message}")
            onConnectionFailure(t, response)
        }
    }

    fun connect() {
        val request = Request.Builder()
            .url(url)
            .build()
        
        webSocket = client.newWebSocket(request, listener)
    }

    fun send(message: String): Boolean {
        return webSocket?.send(message) ?: false
    }

    fun send(bytes: ByteString): Boolean {
        return webSocket?.send(bytes) ?: false
    }

    fun close(code: Int = 1000, reason: String = "Normal closure") {
        webSocket?.close(code, reason)
    }

    fun shutdown() {
        client.dispatcher.executorService.shutdown()
    }

    // Override these methods in your implementation
    open fun onConnectionOpen(webSocket: WebSocket, response: Response) {}
    open fun onTextMessage(text: String) {}
    open fun onBinaryMessage(bytes: ByteString) {}
    open fun onConnectionClosing(code: Int, reason: String) {}
    open fun onConnectionClosed(code: Int, reason: String) {}
    open fun onConnectionFailure(t: Throwable, response: Response?) {}
}

// Usage example
fun main() {
    val client = WebSocketClient("ws://localhost:8080")
    
    // Connect to server
    client.connect()
    
    // Send a message after connection
    Thread.sleep(1000)
    client.send("Hello from Kotlin!")
    
    // Keep connection alive
    Thread.sleep(5000)
    
    // Close connection
    client.close()
    client.shutdown()
}

// Add to build.gradle.kts:
/*
dependencies {
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
}
*/