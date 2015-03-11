package Server;
use strict;
use Text::Trim;
use Digest::SHA1 qw(sha1_base64);
use MIME::Base64;
use utf8;

our $VERSION = "0.01";

my $BYTES_TO_READ = 2048;

sub new {
  my $class = shift;
  my $self = {
    _responseHeader => "HTTP/1.1 101 Web Socket Protocol Handshake\r\n".
    "Upgrade: WebSocket\r\n".
    "Connection: Upgrade\r\n".
    "sec-websocket-accept: %s\r\n\r\n",
    _guidString => "258EAFA5-E914-47DA-95CA-C5AB0DC85B11",
    _handshakeComplete => 0
  };
  bless $self, $class;
  return $self;
}

sub doHandshake {
  my ($self, $client) = @_;
  if($self->{_handshakeComplete} == 1) {
    return;
  }
  my $msg;
  recv($client, $msg, $BYTES_TO_READ, 0);
  # print STDERR "Handshake - received from client: ".$msg."\n";
  my @matches = $msg =~ /Sec-WebSocket-Key:\s+(.*?)[\n\r]+/;
  my $key = trim(shift @matches);
  # print STDERR "Handshake - received key from client: ".$key."\n";
  my $keyEncoded = sha1_base64($key.$self->{_guidString})."=";
  # print STDERR "Handshake - sending to client: ".sprintf($self->{_responseHeader}, $keyEncoded)."\n";
  print $client sprintf($self->{_responseHeader}, $keyEncoded);
  $self->{_handshakeComplete} = 1;
}

sub listen {
  my ($self, $client, $q) = @_;
  my $msg;
  recv($client, $msg, $BYTES_TO_READ, 0);
  # print STDERR "Listen - client says: ".$msg."\n";
  # $msg = $self->unmask($msg);
  # no need to unmask for echo
  # print STDERR "Listen - unmasked message ".$msg."\n";
  $q->enqueue($msg);
}

sub unmask {
  my ($self, $msg) = @_;
  my $length = ord(substr($msg, 1, 1)) & 0x7f;
  # length - low 7 bits at position 1, mask 127, hex 0x7f
  # print STDERR "Unmask - message length ".$length."\n";
  my $mask = "";
  my $data = "";
  my $msgPlain = "";
  if($length == 126) {
    $mask = substr($msg, 4 , 4);
    $data = substr($msg, 8);
  } elsif($length == 127) {
    $mask = substr($msg, 10, 4);
    $data = substr($msg, 14);
  } else {
    $mask = substr($msg, 2, 4);
    $data = substr($msg, 6);
  }

  for(my $i = 0; $i < length($data); $i++) {
    $msgPlain .= substr($data, $i, 1) ^ substr($mask, $i % 4, 1);
  }

  return $msgPlain;
}

sub mask {
  my ($self, $msg) = @_;
  my $b1 = 0x80 | (0x1 & 0x0f);
  # first byte of header
  my $length = length($msg);
  my $header = "";
  if($length <= 125) {
    $header = pack("CC", $b1, $length);
  } elsif($length > 125 && $length < 65536) {
    $header = pack("CCn", $b1, 126, $length);
  } elsif($length >= 65536) {
    $header = pack("CCNN", $b1, 127, $length);
  }
  return $header.$msg;
}

1;
__END__

=head1 NAME

Server - Perl websockets server supporting RFC 6455 standard. 

=head1 SYNOPSIS

Simple broadcast server for C<utf8> messages.

    #!/usr/bin/env perl
    use IO::Socket::INET;
    use threads("yield", 
    "stack_size" => 64 * 4096, 
    "exit" => "threads_only", 
    "stringify");
    use Thread::Queue;
    use Server;
    use BroadcastConsumer;

    my $q = Thread::Queue->new();
    # q
    my $clients = Thread::Queue->new();
    # clients
    my $broadcastThread;
    # broadcastThread;
    $socket = new IO::Socket::INET (
      LocalHost => '127.0.0.1',
      LocalPort => '8080',
      Proto => 'tcp',
      Listen => 10,
      Reuse => 1
    ) or die "Oops: $!\n";
    print STDERR "Server is up and running\n";
    while(1) {
      $clientSocket = $socket->accept();
      push @clients, $clientSocket;
      if(defined $broadcastThread) {
        $broadcastThread->kill("SIGTERM");
      }
      $thread = threads->create(sub {
        $server = new Server();
        $server->doHandshake($clientSocket);
        while(1) {
          $server->listen($clientSocket, $q);
        }
      });
      $thread->detach();
      $broadcastThread = threads->create(sub {
        $SIG{"TERM"} = sub {threads->exit();};
        $broadcastConsumer = new BroadcastConsumer();
        while(1) {
          $broadcastConsumer->broadcast(\@clients, $q);
        }
      });
      $broadcastThread->detach();
    }

=head1 DESCRIPTION

The module implements websockets 6455 standard. It supports concurrent connections using threads and communication based on message queue.

=head1 AUTHOR

scripts E<lt>nikolapav1985@gmail.comE<gt>
