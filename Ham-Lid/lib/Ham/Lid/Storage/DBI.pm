package Ham::Lid::Storage::DBI;

use 5.012004;
use strict;
use warnings;

require Exporter;
use Moose;
use Switch;
use POE qw( Wheel::Run Component::Client::TCP Filter::Stream);
use POE::Component::Child;
use Data::Dumper;
use Data::GUID;
use Ham::Lid::Debug;
use Ham::Lid::Buffer;
use Ham::Lid::Callback;
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
has 'subscribers' => (is => 'rw');
has 'type' => (is => 'rw');
has 'hostname' => (is => 'rw');
has 'port' => (is => 'rw');
has 'username' => (is => 'rw');
has 'password' => (is => 'rw');
has 'database' => (is => 'rw');

sub new {

  my ($class, $manager, $name, $hostname, $port, $callsign) = @_;

  my $g = Data::GUID->new;
  my $self = {
    'version' => $VERSION,
    'id' => $g->as_string,
    'subscribers' => [],
  };

  bless $self, $class;

  if(!defined($manager)) {
    $self->error("No manager passed to session.");
    croak "No manager passed to session.";
  } else {
    $self->manager($manager);
    $self->debug("Manager passed (ID ".$manager->id.")");
  }

  if(!defined($name)) {
    $self->error("No name passed to session.");
    croak "No name passed to session.";
  } else {
    $self->name($name);
    $self->debug("Name passed (".$self->name.")");
  }

  if(!defined($type)) {
    $self->error("No type passed to session.");
    croak "No type passed to session.";
  } else {
    $self->type($type);
    $self->debug("Type passed (".$self->type.")");
  }

  if(!defined($hostname)) {
    $self->error("No hostname passed to session.");
    croak "No hostname passed to session.";
  } else {
    $self->hostname($hostname);
    $self->debug("Hostname passed (".$self->hostname.")");
  }

  if(!defined($port)) {
    $self->error("No port passed to session.");
    croak "No port passed to session.";
  } else {
    $self->port($port);
    $self->debug("Port passed (".$self->port.")");
  }

  if(!defined($username)) {
    $self->error("No username passed to session.");
    croak "No username passed to session.";
  } else {
    $self->username($username);
    $self->debug("Username passed (".$self->username.")");
  }

  if(!defined($password)) {
    $self->error("No username passed to session.");
    croak "No username passed to session.";
  } else {
    $self->password($password);
    $self->debug("Password passed (".$self->password.")");
  }

  if(!defined($database)) {
    $self->error("No database passed to session.");
    croak "No database passed to session.";
  } else {
    $self->database($database);
    $self->debug("Database passed (".$self->database.")");
  }

  $self->debug("new() called.");
  $self->debug("ID is ".$self->id);
  $self->init();

  return $self;
}

sub init {

  my ($self) = @_;
  $self->debug("init() called.");

  # Create buffers to hold data
  $self->buffer(Ham::Lid::Buffer->new);
  $self->buffer->register_callback("out", "default", sub { $self->input($_[0]); });

  $self->session(POE::Session->create(
    inline_states => {
      _start      => sub {
      },
      next    => sub {
        $self->debug("Tick.");
        $self->emit("tick");
        $_[KERNEL]->delay(next => 2);
      },
      input   => sub {
      },
      shutdown => sub {
        $self->debug("[".$self->id."] Session shutdown called.");
        my ($kernel, $session, $heap) = @_[KERNEL, SESSION, HEAP];
        delete $heap->{wheel};
        $kernel->alias_remove($heap->{alias});
        $kernel->delay(next => undef);
      },
      _stop   => sub {
        $self->debug("[".$self->id."] Session stopped.");
      },
    }
  ));

  $self->debug("Registering with manager...");
  $self->out($self->create_message($self->manager->id, "register", {'name' => $self->name, 'type' => ref $self, 'manager' => $self->manager->id, 'buffer' => sub { $self->buffer->in($_[0]); }}));

  $self->debug("init() finished.");
}

sub input {
  my ($self, $data) = @_;
  $self->debug("[".$self->id."] input() called.");
  if(ref $data ne "Ham::Lid::Message")
  {
    $self->error("Message is not of type Ham::Lid::Message!");
    return 0;
  }

  $self->debug("[".$self->id."] I am ".$self->id.", message is for ".$data->destination);

  if($data->destination eq $self->id) {
    $self->debug("[".$self->id."] Message is for me.");
    $self->process($data);
  } else {
    $self->debug("[".$self->id."] Message is not for me.");
    $self->out($data);
  }
  $self->debug("[".$self->id."] input() finished.");
}

sub process {

  my ($self, $data) = @_;

  $self->debug("[".$self->id."] process() called.");
  $self->debug("Command is of type '".$data->type."', and is from '".$data->source."'.");
  switch ($data->type) {
    case "ping" {
      $self->debug("[".$self->id."] 'ping' message received from ".$data->source.".");
      $self->out($self->create_message($data->source, "pong"));
    }
    case "register_ok" {
      $self->debug("Registration successful");
      $self->registered(1);
      $self->start_client();
    }
    case "subscribe" {
      $self->subscribe($data->source);
    }
  }

  $self->debug("[".$self->id."] process() finished.");
}

sub subscribe {
  my ($self, $source) = @_;

  $self->debug("subscribe() called.");

  $self->debug("Adding ".$source." to the subscribers' list.");
  push (@{$self->{subscribers}}, $source);

  $self->debug("subscribe() finished.");
}

sub emit {
  my ($self, $type, $message) = @_;

  $self->debug("emit() called.");

  if(defined($self->subscribers)) {
    foreach my $subscriber (@{$self->subscribers}) {
      my $m = new Ham::Lid::Message({'message' => $message, 'type' => $type, 'source' => $self->id, 'destination' => $subscriber});
      $self->debug("emit(): Processing subscriber ".$subscriber.".");
      $self->out($m);
    }
  }

  $self->debug("emit() finished.");
}

sub create_message {
  my ($self, $destination, $type, $data) = @_;

  my $m = new Ham::Lid::Message({'message' => $data, 'type' => $type, 'source' => $self->id, 'destination' => $destination});

  return $m;
}

sub out {
  my ($self, $msg) = @_;

  $self->debug("ID    : ".$msg->id);
  $self->debug("SOURCE: ".$msg->source);
  $self->debug("DEST  : ".$msg->destination);
  $self->debug("TYPE  : ".$msg->type);

  $self->debug("[".$self->id."] out() called.");
  $self->debug("[".$self->id."] Sending message to ".$msg->destination." of type ".$msg->type.".");
  $self->manager->buffer->in($msg);
  $self->debug("[".$self->id."] out() finished.");
}

1;
