#!/usr/bin/env perl
# Perl WebSocket Client
use strict;
use warnings;
use Protocol::WebSocket::Client;
use IO::Socket::INET;
use IO::Select;

package WebSocketClient;

sub new {
    my ($class, $url) = @_;
    my $self = {
        url => $url,
        client => Protocol::WebSocket::Client->new(url => $url),
        socket => undef,
        connected => 0,
    };
    
    bless $self, $class;
    return $self;
}

sub connect {
    my ($self) = @_;
    
    # Parse URL
    my $url = $self->{url};
    $url =~ s/^ws:\/\///;
    my ($host, $port) = split /:/, $url;
    $port ||= 80;
    
    # Create socket connection
    $self->{socket} = IO::Socket::INET->new(
        PeerAddr => $host,
        PeerPort => $port,
        Proto    => 'tcp',
        Timeout  => 10,
    ) or die "Cannot connect to $host:$port: $!";
    
    print "Connecting to WebSocket server...\n";
    
    # Send WebSocket handshake
    $self->{client}->connect;
    my $handshake = $self->{client}->to_string;
    $self->{socket}->send($handshake);
    
    # Read handshake response
    my $buffer = '';
    while (!$self->{client}->is_connected) {
        my $chunk;
        $self->{socket}->recv($chunk, 1024);
        $buffer .= $chunk;
        $self->{client}->parse($buffer);
    }
    
    if ($self->{client}->is_connected) {
        print "Connected to WebSocket server\n";
        $self->{connected} = 1;
        $self->on_open();
    } else {
        die "Failed to establish WebSocket connection";
    }
}

sub send {
    my ($self, $message) = @_;
    
    if ($self->{connected}) {
        $self->{client}->write($message);
        my $bytes = $self->{client}->to_string;
        $self->{socket}->send($bytes);
        print "Sent: $message\n";
    } else {
        print "Not connected, cannot send message\n";
    }
}

sub listen {
    my ($self) = @_;
    
    my $select = IO::Select->new($self->{socket});
    
    while ($self->{connected}) {
        my @ready = $select->can_read(1);
        
        for my $socket (@ready) {
            my $buffer;
            my $bytes_read = $socket->recv($buffer, 1024);
            
            if (!defined $bytes_read || $bytes_read == 0) {
                print "Connection closed by server\n";
                $self->{connected} = 0;
                $self->on_close();
                last;
            }
            
            $self->{client}->parse($buffer);
            
            while (my $frame = $self->{client}->next_frame) {
                if ($frame->is_text) {
                    my $message = $frame->payload;
                    print "Received: $message\n";
                    $self->on_message($message);
                } elsif ($frame->is_close) {
                    print "Received close frame\n";
                    $self->{connected} = 0;
                    $self->on_close();
                    last;
                }
            }
        }
    }
}

sub close {
    my ($self) = @_;
    
    if ($self->{connected}) {
        $self->{client}->disconnect;
        my $bytes = $self->{client}->to_string;
        $self->{socket}->send($bytes) if $bytes;
        $self->{socket}->close();
        $self->{connected} = 0;
    }
}

# Event handlers - override these in your implementation
sub on_open {
    my ($self) = @_;
    # Override this method
}

sub on_message {
    my ($self, $message) = @_;
    # Override this method
}

sub on_close {
    my ($self) = @_;
    # Override this method
}

# Usage example
package main;

my $client = WebSocketClient->new('ws://localhost:8080');

# Connect to server
$client->connect();

# Send a message
sleep(1);
$client->send('Hello from Perl!');

# Listen for messages in a separate thread
my $pid = fork();
if ($pid == 0) {
    # Child process - listen for messages
    $client->listen();
    exit;
} else {
    # Parent process - keep alive and then close
    sleep(5);
    $client->close();
    kill 'TERM', $pid;
    waitpid($pid, 0);
}

print "WebSocket client finished\n";

# To install required modules:
# cpan Protocol::WebSocket