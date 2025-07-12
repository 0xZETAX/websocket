# Elixir WebSocket Client
defmodule WebSocketClient do
  use GenServer
  require Logger

  @moduledoc """
  A WebSocket client implementation using :gun
  """

  defstruct [:conn_pid, :stream_ref, :url, :state]

  def start_link(url) do
    GenServer.start_link(__MODULE__, url, name: __MODULE__)
  end

  def send_message(message) do
    GenServer.cast(__MODULE__, {:send_message, message})
  end

  def close_connection do
    GenServer.cast(__MODULE__, :close)
  end

  # GenServer callbacks

  @impl true
  def init(url) do
    uri = URI.parse(url)
    
    {:ok, conn_pid} = :gun.open(
      String.to_charlist(uri.host), 
      uri.port || 80,
      %{protocols: [:http]}
    )
    
    case :gun.await_up(conn_pid) do
      {:ok, :http} ->
        stream_ref = :gun.ws_upgrade(conn_pid, uri.path || "/")
        
        state = %__MODULE__{
          conn_pid: conn_pid,
          stream_ref: stream_ref,
          url: url,
          state: :connecting
        }
        
        {:ok, state}
      
      {:error, reason} ->
        Logger.error("Failed to connect: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_cast({:send_message, message}, state) do
    if state.state == :connected do
      :gun.ws_send(state.conn_pid, state.stream_ref, {:text, message})
      Logger.info("Sent: #{message}")
    else
      Logger.warning("Cannot send message, not connected")
    end
    
    {:noreply, state}
  end

  @impl true
  def handle_cast(:close, state) do
    :gun.ws_send(state.conn_pid, state.stream_ref, :close)
    :gun.close(state.conn_pid)
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:gun_upgrade, _conn_pid, _stream_ref, ["websocket"], _headers}, state) do
    Logger.info("Connected to WebSocket server")
    {:noreply, %{state | state: :connected}}
  end

  @impl true
  def handle_info({:gun_ws, _conn_pid, _stream_ref, {:text, message}}, state) do
    Logger.info("Received: #{message}")
    on_message(message)
    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_ws, _conn_pid, _stream_ref, {:binary, data}}, state) do
    Logger.info("Received binary data: #{byte_size(data)} bytes")
    on_binary_message(data)
    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_ws, _conn_pid, _stream_ref, :close}, state) do
    Logger.info("WebSocket connection closed")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:gun_down, _conn_pid, _protocol, _reason, _killed_streams}, state) do
    Logger.info("Connection down")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Override these functions in your implementation
  defp on_message(message) do
    # Handle incoming text message
    IO.puts("Processing message: #{message}")
  end

  defp on_binary_message(data) do
    # Handle incoming binary message
    IO.puts("Processing binary data: #{byte_size(data)} bytes")
  end
end

# Usage example
defmodule WebSocketExample do
  def run do
    # Start the WebSocket client
    {:ok, _pid} = WebSocketClient.start_link("ws://localhost:8080")
    
    # Wait a moment for connection
    :timer.sleep(1000)
    
    # Send a message
    WebSocketClient.send_message("Hello from Elixir!")
    
    # Keep alive for a while
    :timer.sleep(5000)
    
    # Close connection
    WebSocketClient.close_connection()
  end
end

# Add to mix.exs:
# {:gun, "~> 2.0"}