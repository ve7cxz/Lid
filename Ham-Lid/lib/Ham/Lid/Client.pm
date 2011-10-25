package Ham::Lid::Client;

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
use Ham::Lid::Filter;
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
has 'manager' => (is => 'rw');
has 'session' => (is => 'rw');
has 'callbacks' => (is => 'rw');
has 'buffer' => (is => 'rw');
has 'heap' => (is => 'rw');
has 'wheel' => (is => 'rw');
has 'socket' => (is => 'rw');
has 'registered' => (is => 'rw');
has 'authenticated' => (is => 'rw');

sub new {
  my ($class, $manager, $name, $socket) = @_;

  my $g = Data::GUID->new;
  my $self = {
    'version' => $VERSION,
    'id' => $g->as_string
  };

  bless $self, $class;

  if(!defined($manager)) {
    $self->error("No manager passed to client.");
    croak "No manager passed to client.";
  } else {
    $self->manager($manager);
    $self->debug("[".$self->id."] Manager passed (ID ".$manager->id.")");
  }

  if(!defined($name)) {
    $self->error("No 'name' passed to client.");
    croak "No 'name' passed to client.";
  } else {
    $self->name($name);
    $self->debug("[".$self->id."] 'Name' passed (".$name.")");
  }

  if(!defined($socket)) {
    $self->error("No socket passed to client.");
    croak "No socket passed to client.";
  } else {
    $self->socket($socket);
    $self->debug("[".$self->id."] Socket passed.");
  }

  # Create buffers to hold data
  $self->buffer(Ham::Lid::Buffer->new);
  $self->buffer->register_callback("out", "default", sub { $self->in($_[0]); });

  $self->session(POE::Session->create(
    inline_states => {
      _start => sub { 
        my $io_wheel = POE::Wheel::ReadWrite->new(
          Handle => $socket,
          InputEvent => "on_client_input",
          ErrorEvent => "on_client_error",
        );
        $_[HEAP]{client} { $io_wheel->ID() } = $io_wheel;
        $self->wheel($io_wheel);
      },
      on_client_input => sub {
        my ($input, $wheel_id) = @_[ARG0, ARG1];
        $self->client_in($input);
      },
      on_client_error => sub {
        my $wheel_id = $_[ARG3];
        $self->client_error($wheel_id);
        delete $_[HEAP]{client}{$wheel_id};
      },
    }
  ));

  $self->debug("[".$self->id."] new() called.");
  $self->debug("[".$self->id."] ID is ".$self->id);
  $self->debug("[".$self->id."] Name is ".$self->name);
  $self->debug("[".$self->id."] Manager is ".$self->manager->id);
  $self->debug("[".$self->id."] Buffer is ".$self->buffer);

  $self->debug("[".$self->id."] Registering with manager...");
  #$self->manager->register($self->id, $self->name, "daemon", $self->manager->id);
  my $r = $self->create_message($self->manager->id, "register", {'name' => $self->name, 'type' => ref $self, 'manager' => $self->manager->id, 'buffer' => sub { $self->buffer->in($_[0]); }});
  $self->out($r);

  return $self;
}

sub msg {
  my ($self, $msg) = @_;

  $self->debug("[".$self->id."] msg() called.");

  $self->debug("[".$self->id."] msg is ".Dumper($msg));
}

sub client_in {
  my ($self, $msg) = @_;
  $self->debug("[".$self->id."] client_in() called.");
  $self->debug("[".$self->id."] Message is $msg");
  my $f = Ham::Lid::Filter->new("XML", $msg);
  if($f->decode eq 0)
  {
    $self->error("Error decoding message!");
    return 0;
  }
  $self->debug("[".$self->id."] Decoded message is ".$f->decode);
  $self->out($f->decode);
  $self->debug("[".$self->id."] client_in() finished.");
  return;
}

sub client_error {
  my ($self) = @_;
  $self->debug("[".$self->id."] client_error() called.");
  $self->debug("[".$self->id."] Unregistering from manager...");
  $self->out($self->create_message($self->manager->id, "unregister"));
  $self->debug("[".$self->id."] Unregister event sent.");
  $self->debug("[".$self->id."] client_error() finished.");
}

sub client_out {
  my ($self, $msg) = @_;
   $self->debug("[".$self->id."] client_out() called.");
   $self->debug("[".$self->id."] Message is $msg");
   my $f = Ham::Lid::Filter->new("XML", $msg);
   $self->wheel->put($f->encode);
   $self->debug("[".$self->id."] client_out() finished.");
}

sub in {
  my ($self, $data) = @_;

  $self->debug("[".$self->id."] in() called.");
  if($data->destination eq $self->id) {
    $self->debug("[".$self->id."] Message is for me.");
    $self->process($data);
  } else {
    $self->debug("[".$self->id."] Message is not for me.");
    $self->out($data);
  }
  $self->debug("[".$self->id."] in() finished.");
}

sub process {
  my ($self, $data) = @_;

  $self->debug("[".$self->id."] process() called.");
  $self->debug("[".$self->id."] Message from ".$data->source." of type ".$data->type);
  $self->debug("[".$self->id."] Command is of type ".$data->type);
  $self->client_out($data);
  switch ($data->type) {
    case "register_ok" {
      $self->debug("[".$self->id."] Registration successful.");
      $self->registered(1);
      $self->debug("[".$self->id."] Registration done.");
    }
    case "ping" {
      $self->debug("Creating 'pong' message...");
      my $m = $self->create_message($data->source, "pong");
      $self->debug("Sending 'pong' message from ".$self->id." to ".$data->source);
      $self->out($m);
      $self->debug("'pong' message sent.");
    }
    case "pong" {
    }
  }
  $self->debug("[".$self->id."] process() finished.");
}

sub create_message {
  my ($self, $destination, $type, $data) = @_;
  $self->debug("[".$self->id."] create_message() called.");
  
  my $msg = new Ham::Lid::Message({'message' => $data, 'type' => $type, 'source' => $self->id, 'destination' => $destination});

  $self->debug("[".$self->id."] create_message() finished.");
  return $msg;
}

sub out {

  my ($self, $msg) = @_;
  $self->debug("[".$self->id."] out() called.");

  $self->debug("ID    : ".$msg->id);
  $self->debug("SOURCE: ".$msg->source);
  $self->debug("DEST  : ".$msg->destination);
  $self->debug("TYPE  : ".$msg->type);

  if($msg->destination eq $self->id)
  {
    $self->debug("[".$self->id."] Destination is the connected client.");
    $self->client_out($msg);
  } else {
    $self->debug("[".$self->id."] Destination is not the connected client. I am ".$self->id.", and the destination is ".$msg->destination.".");
    $self->manager->buffer->in($msg);
  }
  $self->debug("[".$self->id."] out() finished.");
}

1;
