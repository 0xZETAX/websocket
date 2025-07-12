# R WebSocket Client
library(websocket)
library(later)

# WebSocket Client Class
WebSocketClient <- R6::R6Class("WebSocketClient",
  public = list(
    # Private fields
    .ws = NULL,
    .url = NULL,
    .connected = FALSE,
    
    # Constructor
    initialize = function(url) {
      self$.url <- url
    },
    
    # Connect to WebSocket server
    connect = function() {
      cat("Connecting to", self$.url, "\n")
      
      self$.ws <- websocket::WebSocket$new(self$.url)
      
      # Set event handlers
      self$.ws$onOpen(function(event) {
        cat("Connected to WebSocket server\n")
        self$.connected <- TRUE
        self$on_open(event)
      })
      
      self$.ws$onMessage(function(event) {
        cat("Received:", event$data, "\n")
        self$on_message(event$data)
      })
      
      self$.ws$onClose(function(event) {
        cat("Connection closed\n")
        self$.connected <- FALSE
        self$on_close(event)
      })
      
      self$.ws$onError(function(event) {
        cat("WebSocket error:", event$message, "\n")
        self$on_error(event)
      })
    },
    
    # Send message
    send = function(message) {
      if (self$.connected && !is.null(self$.ws)) {
        self$.ws$send(message)
        cat("Sent:", message, "\n")
      } else {
        cat("Not connected, cannot send message\n")
      }
    },
    
    # Close connection
    close = function() {
      if (!is.null(self$.ws)) {
        self$.ws$close()
        self$.ws <- NULL
        self$.connected <- FALSE
      }
    },
    
    # Check connection status
    is_connected = function() {
      return(self$.connected)
    },
    
    # Event handlers - override these in your implementation
    on_open = function(event) {
      # Override this method
    },
    
    on_message = function(message) {
      # Override this method
    },
    
    on_close = function(event) {
      # Override this method
    },
    
    on_error = function(event) {
      # Override this method
    }
  )
)

# Usage example
main <- function() {
  # Create WebSocket client
  client <- WebSocketClient$new("ws://localhost:8080")
  
  # Override event handlers
  client$on_open <- function(event) {
    cat("Custom onOpen handler called\n")
  }
  
  client$on_message <- function(message) {
    cat("Custom onMessage handler:", message, "\n")
  }
  
  client$on_close <- function(event) {
    cat("Custom onClose handler called\n")
  }
  
  client$on_error <- function(event) {
    cat("Custom onError handler:", event$message, "\n")
  }
  
  # Connect to server
  client$connect()
  
  # Send a message after connection (with delay)
  later::later(function() {
    if (client$is_connected()) {
      client$send("Hello from R!")
      
      # Send JSON message
      json_message <- jsonlite::toJSON(list(
        type = "greeting",
        message = "Hello from R JSON!",
        timestamp = as.numeric(Sys.time())
      ), auto_unbox = TRUE)
      
      client$send(json_message)
    }
  }, delay = 1)
  
  # Close connection after 5 seconds
  later::later(function() {
    client$close()
    cat("WebSocket client finished\n")
  }, delay = 5)
  
  # Keep R session alive to handle events
  cat("WebSocket client running... (will auto-close in 5 seconds)\n")
  
  # Run event loop for 6 seconds
  start_time <- Sys.time()
  while (difftime(Sys.time(), start_time, units = "secs") < 6) {
    later::run_now(timeoutSecs = 0.1)
    Sys.sleep(0.1)
  }
}

# Alternative simple WebSocket client function
simple_websocket_send <- function(url, message) {
  cat("Sending message to", url, "\n")
  
  ws <- websocket::WebSocket$new(url)
  
  ws$onOpen(function(event) {
    cat("Connected, sending message:", message, "\n")
    ws$send(message)
    
    # Close after sending
    later::later(function() {
      ws$close()
    }, delay = 1)
  })
  
  ws$onMessage(function(event) {
    cat("Received response:", event$data, "\n")
  })
  
  ws$onClose(function(event) {
    cat("Connection closed\n")
  })
  
  # Wait for operations to complete
  start_time <- Sys.time()
  while (difftime(Sys.time(), start_time, units = "secs") < 3) {
    later::run_now(timeoutSecs = 0.1)
    Sys.sleep(0.1)
  }
}

# Run the example
if (interactive()) {
  main()
} else {
  # For non-interactive mode
  simple_websocket_send("ws://localhost:8080", "Hello from R script!")
}

# To install required packages:
# install.packages(c("websocket", "later", "R6", "jsonlite"))