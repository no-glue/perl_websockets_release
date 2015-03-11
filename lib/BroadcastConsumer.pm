package BroadcastConsumer;

sub new {
  my ($class) = @_;
  my $self = {
    _clients => [@_]
  };
  bless $self, $class;
  return $self;
}

sub broadcast {
  my ($self, $clients, $q) = @_;
  my $msg = $q->dequeue();
  # print STDERR "msg ".$msg."\n";
  foreach(@$clients) {
    print $_ $msg;
  }
}

1;
__END__
