#!/usr/bin/perl

use strict;
use warnings;

use XML::Simple;
use Data::Dumper;
use POE qw(Component::Client::TCP Wheel::ReadLine);
use Data::GUID;

my $s;
POE::Component::Client::TCP->new(
  RemoteAddress   => "localhost",
  RemotePort      => 4321,
  Connected       => sub { print "Connected.\n"; $s = $_[SESSION]; },
  ServerInput     => sub { server_input($_[ARG0]); },
);

my $c = POE::Session->create(
  inline_states   => {
    _start          => \&setup_console,
    got_user_input  => \&handle_user_input,
  }
);

POE::Kernel->run();

sub server_input {
  print @_;
}

sub handle_user_input {
  my ($input, $exception) = @_[ARG0, ARG1];
  my $console = $_[HEAP]{console};

  unless (defined $input) {
    $console->put("$exception caught.  B'bye!");
    $_[KERNEL]->signal($_[KERNEL], "UIDESTROY");
    $console->write_history("./test_history");
    return;
  }

  $console->put("  You entered: $input");
  $s->get_heap->{server}->put($input);
  $console->addhistory($input);
  $console->get("Go: ");
}

sub setup_console {
  $_[HEAP]{console} = POE::Wheel::ReadLine->new(
    InputEvent => 'got_user_input'
  );
  $_[HEAP]{console}->read_history("./test_history");
  $_[HEAP]{console}->clear();
  $_[HEAP]{console}->put(
    "Enter some text.",
    "Ctrl+C or Ctrl+D exits."
  );
  $_[HEAP]{console}->get("Go: ");
}
