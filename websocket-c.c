// C WebSocket Client (using libwebsockets)
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <libwebsockets.h>

static int interrupted = 0;
static struct lws *websocket_connection = NULL;

// WebSocket callback function
static int callback_websocket(struct lws *wsi, enum lws_callback_reasons reason,
                             void *user, void *in, size_t len) {
    switch (reason) {
        case LWS_CALLBACK_CLIENT_ESTABLISHED:
            printf("Connected to WebSocket server\n");
            // Send a message after connection
            lws_callback_on_writable(wsi);
            break;

        case LWS_CALLBACK_CLIENT_RECEIVE:
            printf("Received: %.*s\n", (int)len, (char *)in);
            break;

        case LWS_CALLBACK_CLIENT_WRITEABLE: {
            const char *message = "Hello from C!";
            size_t message_len = strlen(message);
            unsigned char buf[LWS_PRE + message_len];
            
            memcpy(&buf[LWS_PRE], message, message_len);
            
            int result = lws_write(wsi, &buf[LWS_PRE], message_len, LWS_WRITE_TEXT);
            if (result < 0) {
                printf("Failed to send message\n");
                return -1;
            }
            printf("Sent: %s\n", message);
            break;
        }

        case LWS_CALLBACK_CLIENT_CONNECTION_ERROR:
            printf("Connection error\n");
            websocket_connection = NULL;
            break;

        case LWS_CALLBACK_CLOSED:
            printf("Connection closed\n");
            websocket_connection = NULL;
            break;

        default:
            break;
    }

    return 0;
}

// Protocol definition
static struct lws_protocols protocols[] = {
    {
        "websocket-protocol",
        callback_websocket,
        0,
        1024,
    },
    { NULL, NULL, 0, 0 } // terminator
};

// Signal handler for graceful shutdown
void sigint_handler(int sig) {
    interrupted = 1;
}

int main() {
    struct lws_context_creation_info info;
    struct lws_context *context;
    struct lws_client_connect_info connect_info;
    
    // Set up signal handler
    signal(SIGINT, sigint_handler);
    
    // Initialize context creation info
    memset(&info, 0, sizeof(info));
    info.port = CONTEXT_PORT_NO_LISTEN;
    info.protocols = protocols;
    info.gid = -1;
    info.uid = -1;
    
    // Create context
    context = lws_create_context(&info);
    if (!context) {
        printf("Failed to create libwebsockets context\n");
        return 1;
    }
    
    // Set up connection info
    memset(&connect_info, 0, sizeof(connect_info));
    connect_info.context = context;
    connect_info.address = "localhost";
    connect_info.port = 8080;
    connect_info.path = "/";
    connect_info.host = connect_info.address;
    connect_info.origin = connect_info.address;
    connect_info.protocol = protocols[0].name;
    
    // Connect to WebSocket server
    websocket_connection = lws_client_connect_via_info(&connect_info);
    if (!websocket_connection) {
        printf("Failed to connect to WebSocket server\n");
        lws_context_destroy(context);
        return 1;
    }
    
    // Main event loop
    while (!interrupted && websocket_connection) {
        lws_service(context, 1000);
    }
    
    // Cleanup
    lws_context_destroy(context);
    printf("WebSocket client terminated\n");
    
    return 0;
}

/*
To compile:
gcc -o websocket_client websocket-c.c -lwebsockets

To install libwebsockets on Ubuntu/Debian:
sudo apt-get install libwebsockets-dev

To install libwebsockets on macOS:
brew install libwebsockets
*/