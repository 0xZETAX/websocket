// C++ WebSocket Client (using websocketpp)
#include <websocketpp/config/asio_no_tls_client.hpp>
#include <websocketpp/client.hpp>
#include <iostream>
#include <string>
#include <thread>
#include <chrono>

typedef websocketpp::client<websocketpp::config::asio_client> client;

class WebSocketClient {
private:
    client ws_client;
    websocketpp::connection_hdl hdl;
    std::thread ws_thread;
    bool connected;

public:
    WebSocketClient() : connected(false) {
        // Set logging settings
        ws_client.set_access_channels(websocketpp::log::alevel::all);
        ws_client.clear_access_channels(websocketpp::log::alevel::frame_payload);
        
        // Initialize ASIO
        ws_client.init_asio();
        
        // Set message handlers
        ws_client.set_message_handler([this](websocketpp::connection_hdl hdl, client::message_ptr msg) {
            this->on_message(hdl, msg);
        });
        
        ws_client.set_open_handler([this](websocketpp::connection_hdl hdl) {
            this->on_open(hdl);
        });
        
        ws_client.set_close_handler([this](websocketpp::connection_hdl hdl) {
            this->on_close(hdl);
        });
        
        ws_client.set_fail_handler([this](websocketpp::connection_hdl hdl) {
            this->on_fail(hdl);
        });
    }
    
    ~WebSocketClient() {
        close();
    }
    
    bool connect(const std::string& uri) {
        websocketpp::lib::error_code ec;
        client::connection_ptr con = ws_client.get_connection(uri, ec);
        
        if (ec) {
            std::cout << "Could not create connection: " << ec.message() << std::endl;
            return false;
        }
        
        hdl = con->get_handle();
        ws_client.connect(con);
        
        // Start the ASIO io_service run loop in a separate thread
        ws_thread = std::thread([this]() {
            ws_client.run();
        });
        
        return true;
    }
    
    void send(const std::string& message) {
        if (connected) {
            websocketpp::lib::error_code ec;
            ws_client.send(hdl, message, websocketpp::frame::opcode::text, ec);
            
            if (ec) {
                std::cout << "Send failed: " << ec.message() << std::endl;
            } else {
                std::cout << "Sent: " << message << std::endl;
            }
        } else {
            std::cout << "Not connected, cannot send message" << std::endl;
        }
    }
    
    void close() {
        if (connected) {
            websocketpp::lib::error_code ec;
            ws_client.close(hdl, websocketpp::close::status::going_away, "", ec);
            
            if (ec) {
                std::cout << "Close failed: " << ec.message() << std::endl;
            }
        }
        
        if (ws_thread.joinable()) {
            ws_thread.join();
        }
    }
    
    bool is_connected() const {
        return connected;
    }

private:
    void on_open(websocketpp::connection_hdl hdl) {
        std::cout << "Connected to WebSocket server" << std::endl;
        connected = true;
        this->hdl = hdl;
    }
    
    void on_message(websocketpp::connection_hdl hdl, client::message_ptr msg) {
        std::cout << "Received: " << msg->get_payload() << std::endl;
    }
    
    void on_close(websocketpp::connection_hdl hdl) {
        std::cout << "Connection closed" << std::endl;
        connected = false;
    }
    
    void on_fail(websocketpp::connection_hdl hdl) {
        std::cout << "Connection failed" << std::endl;
        connected = false;
    }
};

// Usage example
int main() {
    WebSocketClient client;
    
    // Connect to WebSocket server
    if (!client.connect("ws://localhost:8080")) {
        std::cout << "Failed to connect" << std::endl;
        return 1;
    }
    
    // Wait for connection to establish
    std::this_thread::sleep_for(std::chrono::seconds(1));
    
    // Send a message
    client.send("Hello from C++!");
    
    // Keep connection alive
    std::this_thread::sleep_for(std::chrono::seconds(5));
    
    // Close connection
    client.close();
    
    return 0;
}

/*
To compile:
g++ -std=c++11 -o websocket_client websocket-cpp.cpp -lboost_system -lpthread

To install websocketpp on Ubuntu/Debian:
sudo apt-get install libwebsocketpp-dev libboost-system-dev

To install websocketpp on macOS:
brew install websocketpp boost
*/