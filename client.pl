#!/usr/bin/perl

use strict;
use warnings;

use XML::Simple;
use Switch;
use Data::Dumper;
use POE qw(Component::Client::TCP Wheel::ReadLine);
use Data::GUID;
use Ham::Lid::Message;
use Ham::Lid::Filter;

my $manager;
my $id;

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
  my ($msg) = @_;
  process($msg);
}

sub process {
  my ($msg) = @_;
  my $f = Ham::Lid::Filter->new("XML", $msg);
  my $data = $f->decode;

  if(!$@)
  {
    switch ($data->type) {
      case "register_ok" {
        print "\nRegistration successful.\n";
        print "I am ".$data->destination.", manager is ".$data->source.".\n";
        $manager = $data->source;
        $id = $data->destination;
      }
      case "pong" {
        print "Pong receieved.\n";
      }
    }
  }
}

sub command {
  my ($cmd) = @_;

  my ($c) = $cmd =~ m/^(\w+)/;
  print "COMMAND: $c\n";

  my $o;
  switch($c) {
    case "ping" {
      my $m = Ham::Lid::Message->new({source => $id, destination => $manager, type => "ping"});
      $o = Ham::Lid::Filter->new("XML", $m);
      print "Sent ping to manager...\n";
    }
  }
  
  if(defined($o))
  {
    $s->get_heap->{server}->put($o->encode);
  }
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
  $console->addhistory($input);
  command($input);
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
