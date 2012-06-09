package Ham::Lid::Daemon;

use 5.012004;
use strict;
use warnings;

require Exporter;
use Moose;
use Switch;
use POE qw( Wheel::Run );
use POE::Component::Child;
use Data::Dumper;
use Data::GUID;
use Ham::Lid::Debug;
use Ham::Lid::Buffer;
use Ham::Lid::Callback;
use Ham::Lid::Message;
use Ham::Lid::Client;
use POE::Component::Server::TCP;
use Carp;
use base qw(Ham::Lid::Debug Ham::Lid::Callback);
our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Ham::Lid ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';

BEGIN {
  __PACKAGE__->debug("Loaded.");
}

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.
has 'id' => (is => 'rw');
has 'name' => (is => 'rw');
has 'session' => (is => 'rw');
has 'callbacks' => (is => 'rw');
has 'buffer' => (is => 'rw');
has 'manager' => (is => 'rw');
has 'heap' => (is => 'rw');
has 'registered' => (is => 'rw');
has 'count' => (is => 'rw');

sub new {

  my ($class, $manager, $name, $options) = @_;

  my $g = Data::GUID->new;
  my $self = {
    'version' => $VERSION,
    'id' => $g->as_string,
    'count' => 0
  };

  bless $self, $class;

  if(!defined($manager)) {
    $self->error("No manager passed to session.");
    croak "No manager passed to session.";
  } else {
    $self->manager($manager);
    $self->debug("Manager passed.");
  }

  if(!defined($name)) {
    $self->error("No 'name' passed to session.");
    croak "No 'name' passed to session.";
  } else {
    $self->name($name);
    $self->debug("'Name' passed (".$name.")");
  }

  # Create buffers to hold data
  $self->buffer(Ham::Lid::Buffer->new);
  $self->buffer->register_callback("out", "default", sub { $self->in($_[0]); });

  $self->debug("new() called.");
  $self->debug("ID is ".$self->id);
  $self->debug("Name is ".$self->name);
  $self->debug("Buffer is ".$self->buffer->id);

  $self->session(POE::Session->create(
    inline_states => {
      _start => sub {
        $self->debug("_start triggered");
        $_[KERNEL]->alias_set($self->name);
        $self->debug("Registering with manager...");
        $self->out($self->create_message('manager', "register", {'name' => $self->name, 'type' => ref $self, 'manager' => 'manager'}));

        $_[HEAP]{server} = POE::Wheel::SocketFactory->new(
          BindAddress   => $options->{address},
          BindPort      => $options->{port},
          SuccessEvent  => "on_client_accept",
          FailureEvent  => "on_server_error",
        );

        $_[KERNEL]->yield('tick');
      },
      on_client_accept => sub {
        $self->debug("on_client_accept triggered");
        Ham::Lid::Client->new($self->manager, $self->name."_client_".$self->count, $_[ARG0]);
        $self->count($self->count + 1);
      },
      on_server_error => sub {
        $self->debug("on_server_error triggered");
        my ($op, $errnum, $errstr) = @_[ARG0, ARG1, ARG2];
        $self->error("Server $op error $errnum: $errstr");
        delete $_[HEAP]{server};

        $self->debug("Waiting 2 seconds before attempting to bind port again.");
        sleep 2;
        $_[HEAP]{server} = POE::Wheel::SocketFactory->new(
          BindPort => 4321,
          SuccessEvent => "on_client_accept",
          FailureEvent => "on_server_error",
        );
      },
      in => sub {
        $self->debug("in triggered");
        $self->buffer->in($_[ARG0]);
      },
      tick => sub {
        $self->debug("tick triggered");
        $_[KERNEL]->delay(tick => 1);
      }
    },
  ));

  return $self;
}

sub in {
  my ($self, $data) = @_;

  $self->debug("in() called.");
  if($data->destination eq $self->name) {
    $self->debug("Message is for me.");
    $self->process($data);
  } else {
    $self->debug("Message is not for me.");
    $self->out($data);
  }
  $self->debug("in() finished.");
}

sub process {
  my ($self, $data) = @_;

  $self->debug("process() called.");
  $self->debug("Message from ".$data->source." of type ".$data->type);
#  if($data->type eq "register_ok") {
  switch ($data->type) {
    case "register_ok" {
      $self->debug("Registration successful.");
      $self->registered(1);
    }
    case "ping" {
      $self->out($data->source, "pong");
    }
  }
#  }
  $self->debug("process() finished.");
}

sub create_message {
  my ($self, $destination, $type, $data) = @_;

  $self->debug("create_message() called.");

  my $m = new Ham::Lid::Message({'message' => $data, 'type' => $type, 'source' => $self->id, 'destination' => $destination});

  $self->debug("create_message() finished.");

  return $m;
}

sub out {
  my ($self, $msg) = @_;

  $self->debug("out() called.");
  if(ref $msg ne "Ham::Lid::Message") {
    $self->error("Message is not of type Ham::Lid::Message!");
    return 0;
  }
  $poe_kernel->post($poe_kernel->alias_resolve("manager"), 'in', $msg);
  $self->debug("out() finished.");
}

1;
