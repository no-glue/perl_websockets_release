# NAME

Server - Perl websockets server supporting RFC 6455 standard. 

# SYNOPSIS

Simple broadcast server for `utf8` messages.

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

# DESCRIPTION

The module implements websockets 6455 standard. It supports concurrent connections using threads and communication based on message queue.

# AUTHOR

scripts <nikolapav1985@gmail.com>
