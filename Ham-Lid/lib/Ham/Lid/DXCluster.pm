package Ham::Lid::DXCluster;

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
use Ham::Lid::DXCluster::Filter;
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
has 'client_session' => (is => 'rw');
has 'callbacks' => (is => 'rw');
has 'buffer' => (is => 'rw');
has 'manager' => (is => 'rw');
has 'heap' => (is => 'rw');
has 'registered' => (is => 'rw');
has 'subscribers' => (is => 'rw');
has 'callsign' => (is => 'rw');
has 'hostname' => (is => 'rw');
has 'port' => (is => 'rw');
has 'cluster_name' => (is => 'rw');
has 'client_buffer' => (is => 'rw');
has 'options' => (is => 'rw');
has 'filters' => (is => 'rw');

sub new {

  my ($class, $manager, $name, $config) = @_;

  my $g = Data::GUID->new;
  my $self = {
    'version' => $VERSION,
    'id' => $g->as_string,
    'subscribers' => [],
    'options' => $config,
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

  if(!defined($config->{hostname})) {
    $self->error("No hostname passed to session.");
    croak "No hostname passed to session.";
  } else {
    $self->hostname($config->{hostname});
    $self->debug("Hostname passed (".$self->hostname.")");
  }

  if(!defined($config->{port})) {
    $self->error("No port passed to session.");
    croak "No port passed to session.";
  } else {
    $self->port($config->{port});
    $self->debug("Port passed (".$self->port.")");
  }

  if(!defined($config->{callsign})) {
    $self->error("No callsign passed to session.");
    croak "No callsign passed to session.";
  } else {
    $self->callsign($config->{callsign});
    $self->debug("Callsign passed (".$self->callsign.")");
  }

  $self->debug("new() called.");
  $self->debug("ID is ".$self->id);

  # Check for any filters in the options
  if($self->options->{filters}) {
    $self->debug("[".$self->name."] Loading filters...");
    my $filters = $self->options->{filters}[0]{filter};
    while( my($key, $value) = each(%$filters) ) {
      $self->debug("[".$self->name."] Loading '".$key."' filter...");
      my $filter = Ham::Lid::DXCluster::Filter->new($filters->{$key});
      $self->{filters}{$key} = $filter;
    }
  }

  # Check for any subscribers in the options
  if($self->options->{subscriptions}) {
    $self->debug("[".$self->name."] Loading subscriptions...");
    my $subscriptions = $self->options->{subscriptions}[0]{subscription};
    while( my($key, $value) = each(%$subscriptions) ) {
      $self->debug("[".$self->name."] Loading '".$key."' subscription...");
      $self->debug("[".$self->name."] Module ".$value->{subscriber}." wants to subscribe to ".$value->{event}." events, filtered through ".$value->{filter}." and sending to ".$value->{subscriber_handler}.".");
#      my $filter = Ham::Lid::DXCluster::Filter->new($filters->{$key});
#      $self->{filters}{$key} = $filter;
    }
  }
  $self->init();

  return $self;
}

sub init {

  my ($self) = @_;
  $self->debug("init() called.");

  # Create buffers to hold data
  $self->buffer(Ham::Lid::Buffer->new);
  $self->client_buffer(Ham::Lid::Buffer->new);
#  $self->buffer->register_callback("out", "default", sub { $self->input($_[0]); });
  $self->client_buffer->register_callback("out", "default", sub { $self->client_input($_[0]); });

  $self->session(POE::Session->create(
    inline_states => {
      _start      => sub {
        $self->debug("[".$self->name."] Starting client...");

        $_[KERNEL]->alias_set($self->name);

        $self->debug("Registering with manager...");
        $self->out($self->create_message($self->manager->id, "register", {'name' => $self->name, 'type' => ref $self, 'manager' => $self->manager->id}));

        $_[HEAP]{server} = POE::Wheel::SocketFactory->new(
          #RemoteAddress     => "gb7mbc.spoo.org",
          #RemotePort        => 8000,
          RemoteAddress     => $self->hostname,
          RemotePort        => $self->port,,
          #Started           => sub { $self->debug("[".$self->name."] Started connection to ".$self->hostname.", port ".$self->port."."); },
          SuccessEvent      => "on_connect",
          FailureEvent      => "on_failure",
        );

        $self->debug("[".$self->name."] Client started.");        
        $_[KERNEL]->yield("next");
      },
      on_connect  => sub {
        $self->debug("[".$self->name."] Connected.");
        my $client_socket = $_[ARG0];

        my $wheel = POE::Wheel::ReadWrite->new(
          Handle      => $client_socket,
          InputEvent  => "on_input",
          ErrorEvent  => "on_error",
          Filter      => POE::Filter::Stream->new(),
        );
        #$_[HEAP]{client}{$wheel->ID()} = $wheel;
        $_[HEAP]{client} = $wheel;
      },
      on_input    => sub {
        $self->debug("[".$self->name."] on_input event called.");
        $self->client_input($_[ARG0]);
      },
      on_failure  => sub {
        $self->debug("[".$self->name."] on_failure event called.");
        $self->debug("[".$self->name."] Could not connect to ".$self->hostname.", port ".$self->port.".");
        $self->out($self->create_message($self->manager->id, "unregister"));
        $_[KERNEL]->post($self->session, 'shutdown');
        $_[KERNEL]->yield('shutdown');
      },
      on_error    => sub {
        $self->debug("[".$self->name."] on_error event called.");
        $self->debug("[".$self->name."] Error in connection to ".$self->hostname.", port ".$self->port.".");
        $self->out($self->create_message($self->manager->id, "unregister"));
        $_[KERNEL]->post($self->session, 'shutdown');
        $_[KERNEL]->yield('shutdown');
      },
      next    => sub {
        $_[KERNEL]->delay(next => 1);
      },
      in   => sub {
        $self->input($_[ARG0]);
      },
      shutdown => sub {
        $self->debug("[".$self->name."] Session shutdown called.");
        my ($kernel, $session, $heap) = @_[KERNEL, SESSION, HEAP];
        delete $heap->{wheel};
        delete $heap->{client};
        delete $heap->{server};
        $kernel->alias_remove($heap->{alias});
        $kernel->delay(next => undef);
      },
      _stop   => sub {
        $self->debug("[".$self->name."] Session stopped.");
      },
    }
  ));

  $self->debug("init() finished.");
}

sub input {
  my ($self, $data) = @_;
  $self->debug("[".$self->name."] input() called.");
  if(ref $data ne "Ham::Lid::Message")
  {
    $self->error("Message is not of type Ham::Lid::Message!");
    return 0;
  }

  $self->debug("[".$self->name."] I am ".$self->id.", message is for ".$data->destination);

  if($data->destination eq $self->id) {
    $self->debug("[".$self->name."] Message is for me.");
    $self->process($data);
  } else {
    $self->debug("[".$self->name."] Message is not for me.");
    $self->out($data);
  }
  $self->debug("[".$self->name."] input() finished.");
}

sub client_input {
  my ($self, $data) = @_;
  $self->debug("[".$self->name."] client_input() called.");

  $self->client_process($data);

  $self->debug("[".$self->name."] client_input() finished.");
}

sub process {

  my ($self, $data) = @_;

  $self->debug("[".$self->name."] process() called.");
  $self->debug("Command is of type '".$data->type."', and is from '".$data->source."'.");
  switch ($data->type) {
    case "ping" {
      $self->debug("[".$self->name."] 'ping' message received from ".$data->source.".");
      $self->out($self->create_message($data->source, "pong"));
    }
    case "register_ok" {
      $self->debug("Registration successful");
      $self->registered(1);
    }
    case "subscribe" {
      $self->subscribe($data->source);
    }
  }

  $self->debug("[".$self->name."] process() finished.");
}

sub client_process {

  my ($self, $data) = @_;

  $self->debug("[".$self->name."] client_process() called.");

  my @lines = split(/\n/, $data);

  foreach my $line (@lines) {
    if($line =~ m/^login: /) {
      $self->debug("[".$self->name."] Got DX cluster login prompt. Sending callsign (".$self->callsign.")...");
      $self->client_out($self->callsign."\n");
    } elsif($line =~ m/^(\S+)>/) {
      $self->debug("[".$self->name."] Got DX cluster prompt: ".$1);
      $self->cluster_name($1);
    } elsif($line =~ m/^DX de (\w+):\s+(\d+.\d+)\s+(\S+)\s+(.*)\s+(\d+Z)\s?(\w*)/) {
      $self->debug("[".$self->name."] Got DX spot from $1 (in $6) of $3 on $2 at $5 (comment: $4).");
      my $dxspot = {
        'spotter'   => $1,
        'callsign'  => $3,
        'frequency' => $2,
        'timestamp' => $5,
        'comment'   => $4,
      };
      if($6) {
        $dxspot->{'locator'} = $6;
      }
      #$self->filters->{'m0vkg_dx_filter'}->process($dxspot);
    } elsif($line =~ m/^To LOCAL de (\w+):\s(.*)/) {
      $self->debug("[".$self->name."] Got LOCAL ANNOUNCE from $1: $2.");
    }
  }

  $self->client_buffer(undef);

  $self->debug("[".$self->name."] client_process() finished.");
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

  $self->debug("[".$self->name."] out() called.");
  $self->debug("[".$self->name."] Sending message to ".$msg->destination." of type ".$msg->type.".");
  $poe_kernel->post($poe_kernel->alias_resolve('manager'), 'in', $msg);
  $self->debug("[".$self->name."] out() finished.");
}

sub client_out {
  my ($self, $msg) = @_;

  $self->debug("[".$self->name."] client_out() called.");

  $self->debug("[".$self->name."] Sending data...");

  $self->session->get_heap->{client}->put($msg);

  $self->debug("[".$self->name."] client_out() finished.");
}

1;
