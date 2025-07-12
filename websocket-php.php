<?php
// PHP WebSocket Client using ReactPHP
require_once 'vendor/autoload.php';

use Ratchet\Client\WebSocket;
use Ratchet\Client\Connector;

class WebSocketClient {
    private $connector;
    private $connection;
    private $url;

    public function __construct($url) {
        $this->url = $url;
        $this->connector = new Connector();
    }

    public function connect() {
        return $this->connector($this->url)
            ->then(function (WebSocket $conn) {
                $this->connection = $conn;
                echo "Connected to WebSocket server\n";

                $conn->on('message', function ($msg) {
                    $this->onMessage($msg->getPayload());
                });

                $conn->on('close', function ($code = null, $reason = null) {
                    echo "Connection closed ({$code} - {$reason})\n";
                });

                return $conn;
            }, function (\Exception $e) {
                echo "Could not connect: {$e->getMessage()}\n";
            });
    }

    public function send($message) {
        if ($this->connection) {
            $this->connection->send($message);
            echo "Sent: {$message}\n";
        }
    }

    public function close() {
        if ($this->connection) {
            $this->connection->close();
        }
    }

    protected function onMessage($message) {
        echo "Received: {$message}\n";
    }
}

// Usage example
$loop = \React\EventLoop\Factory::create();
$client = new WebSocketClient('ws://localhost:8080');

$client->connect()->then(function () use ($client) {
    // Send a message after connection
    $client->send('Hello from PHP!');
    
    // Close after 5 seconds
    $loop->addTimer(5, function () use ($client) {
        $client->close();
    });
});

$loop->run();
?>