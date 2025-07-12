#!/bin/bash
# Shell WebSocket Client (using websocat)

# WebSocket client configuration
WEBSOCKET_URL="ws://localhost:8080"
MESSAGE="Hello from Shell!"
TIMEOUT=5

# Function to check if websocat is installed
check_websocat() {
    if ! command -v websocat &> /dev/null; then
        echo "Error: websocat is not installed"
        echo "Install it with:"
        echo "  # On Ubuntu/Debian:"
        echo "  wget https://github.com/vi/websocat/releases/download/v1.11.0/websocat.x86_64-unknown-linux-musl"
        echo "  chmod +x websocat.x86_64-unknown-linux-musl"
        echo "  sudo mv websocat.x86_64-unknown-linux-musl /usr/local/bin/websocat"
        echo ""
        echo "  # On macOS:"
        echo "  brew install websocat"
        echo ""
        echo "  # Or download from: https://github.com/vi/websocat/releases"
        exit 1
    fi
}

# Function to send a single message
send_message() {
    local url="$1"
    local message="$2"
    
    echo "Connecting to $url..."
    echo "Sending: $message"
    
    # Send message and close connection
    echo "$message" | websocat "$url" --exit-on-eof
    
    if [ $? -eq 0 ]; then
        echo "Message sent successfully"
    else
        echo "Failed to send message"
        return 1
    fi
}

# Function for interactive WebSocket session
interactive_session() {
    local url="$1"
    
    echo "Starting interactive WebSocket session with $url"
    echo "Type messages and press Enter to send. Type 'quit' to exit."
    echo "----------------------------------------"
    
    # Create named pipes for bidirectional communication
    local input_pipe="/tmp/ws_input_$$"
    local output_pipe="/tmp/ws_output_$$"
    
    mkfifo "$input_pipe" "$output_pipe"
    
    # Start websocat in background
    websocat "$url" < "$input_pipe" > "$output_pipe" &
    local websocat_pid=$!
    
    # Start output reader in background
    (
        while IFS= read -r line; do
            echo "Received: $line"
        done < "$output_pipe"
    ) &
    local reader_pid=$!
    
    # Handle user input
    exec 3>"$input_pipe"
    
    echo "Connected to WebSocket server"
    
    while true; do
        read -r -p "> " user_input
        
        if [ "$user_input" = "quit" ]; then
            break
        fi
        
        echo "$user_input" >&3
        echo "Sent: $user_input"
    done
    
    # Cleanup
    exec 3>&-
    kill $websocat_pid $reader_pid 2>/dev/null
    rm -f "$input_pipe" "$output_pipe"
    
    echo "WebSocket session ended"
}

# Function to listen for messages
listen_messages() {
    local url="$1"
    local duration="$2"
    
    echo "Listening for messages from $url for $duration seconds..."
    
    # Listen for messages with timeout
    timeout "$duration" websocat "$url" --print-ping-pongs
    
    echo "Listening session ended"
}

# Function to send periodic messages
send_periodic() {
    local url="$1"
    local message="$2"
    local interval="$3"
    local count="$4"
    
    echo "Sending '$message' every $interval seconds, $count times"
    
    for ((i=1; i<=count; i++)); do
        echo "[$i/$count] Sending: $message"
        echo "$message (message $i)" | websocat "$url" --exit-on-eof
        
        if [ $i -lt $count ]; then
            sleep "$interval"
        fi
    done
    
    echo "Periodic sending completed"
}

# Main script logic
main() {
    check_websocat
    
    case "${1:-send}" in
        "send")
            send_message "$WEBSOCKET_URL" "$MESSAGE"
            ;;
        "interactive")
            interactive_session "$WEBSOCKET_URL"
            ;;
        "listen")
            listen_messages "$WEBSOCKET_URL" "${2:-10}"
            ;;
        "periodic")
            send_periodic "$WEBSOCKET_URL" "$MESSAGE" "${2:-2}" "${3:-5}"
            ;;
        "help")
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  send         Send a single message (default)"
            echo "  interactive  Start interactive session"
            echo "  listen [sec] Listen for messages (default: 10 seconds)"
            echo "  periodic [interval] [count] Send periodic messages"
            echo "  help         Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 send"
            echo "  $0 interactive"
            echo "  $0 listen 30"
            echo "  $0 periodic 3 10"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"