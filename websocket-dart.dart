// Dart WebSocket Client
import 'dart:io';
import 'dart:convert';
import 'dart:async';

class WebSocketClient {
  WebSocket? _webSocket;
  String _url;
  StreamSubscription? _subscription;
  
  WebSocketClient(this._url);

  Future<void> connect() async {
    try {
      _webSocket = await WebSocket.connect(_url);
      print('Connected to WebSocket server');
      
      _subscription = _webSocket!.listen(
        (data) {
          print('Received: $data');
          _onMessage(data);
        },
        onError: (error) {
          print('WebSocket error: $error');
          _onError(error);
        },
        onDone: () {
          print('Connection closed');
          _onClose();
        },
      );
      
      _onOpen();
    } catch (e) {
      print('Connection failed: $e');
      _onError(e);
    }
  }

  void send(String message) {
    if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
      _webSocket!.add(message);
      print('Sent: $message');
    } else {
      print('WebSocket is not connected');
    }
  }

  void sendJson(Map<String, dynamic> data) {
    send(jsonEncode(data));
  }

  Future<void> close() async {
    await _subscription?.cancel();
    await _webSocket?.close();
    _webSocket = null;
  }

  // Event handlers - override these in your implementation
  void _onOpen() {
    onOpen();
  }

  void _onMessage(dynamic message) {
    onMessage(message);
  }

  void _onClose() {
    onClose();
  }

  void _onError(dynamic error) {
    onError(error);
  }

  // Override these methods in your implementation
  void onOpen() {}
  void onMessage(dynamic message) {}
  void onClose() {}
  void onError(dynamic error) {}

  // Getters
  bool get isConnected => 
    _webSocket != null && _webSocket!.readyState == WebSocket.open;
  
  int? get readyState => _webSocket?.readyState;
}

// Usage example
void main() async {
  final client = WebSocketClient('ws://localhost:8080');
  
  // Override event handlers
  client.onOpen = () {
    print('Custom onOpen handler');
  };
  
  client.onMessage = (message) {
    print('Custom onMessage handler: $message');
  };
  
  client.onClose = () {
    print('Custom onClose handler');
  };
  
  client.onError = (error) {
    print('Custom onError handler: $error');
  };

  // Connect to server
  await client.connect();
  
  // Send a message after connection
  await Future.delayed(Duration(seconds: 1));
  client.send('Hello from Dart!');
  
  // Send JSON message
  client.sendJson({
    'type': 'greeting',
    'message': 'Hello from Dart JSON!',
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  });
  
  // Keep connection alive
  await Future.delayed(Duration(seconds: 5));
  
  // Close connection
  await client.close();
}