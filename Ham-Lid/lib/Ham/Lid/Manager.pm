package Ham::Lid::Manager;

# Things are shaping up to be pretty odd...

use 5.012004;
use strict;
use warnings;

require Exporter;
use Moose;
use Switch;
use Carp;
use POE qw( Wheel::Run );
use Data::Dumper;
use Data::GUID;
use Ham::Lid::Debug;
use Ham::Lid::Session;
use Module::Load;
use POE::Wheel::ReadWrite;
use XML::Simple;
use base qw(Ham::Lid::Debug);
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
has 'session' => (is => 'rw');
has 'sessions' => (is => 'rw');
has 'id' => (is => 'rw');
has 'buffer' => (is => 'rw');
has 'register_table' => (is => 'rw');
has 'config' => (is => 'rw');

sub new {

  my $class = shift;
  my $g = Data::GUID->new;
  my $self = {
    'version' => $VERSION,
    'id' => $g->as_string,
    'sessions' => {},
    'register_table' => {}
  };

  bless $self, $class;
  $self->debug("[".$self->id."] new() called.");

  # Create input buffer
  $self->buffer(new Ham::Lid::Buffer);
  $self->buffer->register_callback("out", "default", sub { $self->input($_[0]); } );

  $self->session(POE::Session->create(
    inline_states => {
      _start => sub {
        $self->debug("_start triggered");
        $_[KERNEL]->alias_set("manager");
        $_[KERNEL]->yield("tick");
      },
      tick => sub {
        $self->debug("tick triggered");
        $self->debug("Kernel tick");
        $_[KERNEL]->delay(tick => 1);
      },
      in   => sub {
        $self->buffer->in($_[ARG0]);
      },
    }
  ));

  $self->load_config;
  $self->load_modules;

  # Start console
  #my $console = new Ham::Lid::Console($self);
  #new Ham::Lid::Daemon($self, "daemon_4321");
  #new Ham::Lid::Auth($self, "authenticator");
  #new Ham::Lid::Console($self, "console");
  #new Ham::Lid::Example($self, "example");
  #new Ham::Lid::DXCluster($self, "dxcluster", "localhost", "7300", "M0VKG");

  $self->start();
  $self->debug("[".$self->id."] new() finished.");
  return $self;
}

sub load_config {
  my ($self) = @_;

  $self->debug("load_config() called.");
  my $x = XML::Simple->new(ForceArray => 1);

  my $l = ['/etc/lid/config.xml', '~/.lid/config.xml', './config.xml'];

  foreach my $location (@{$l}) {
    $self->debug("Attempting to load configuration file from ".$location."...");
    if(-f $location) {
      $self->debug("Found ".$location);
      $self->config($x->XMLin($location));
      if($@) {
        $self->error("Error loading ".$location."!");
      } else {
        $self->debug("Successfully loaded config from ".$location.".");
        $self->debug("load_config() finished.");
        return;
      }
    }
  }

  $self->error("Couldn't find a working configuration file!");
  croak "Couldn't find a working configuration file!\n";

}

sub load_module {
  my ($self, $module, $name, $options) = @_;

  $self->debug("load_module() called.");
  $self->debug("load_module(): Loading ".$name."...");
  $self->debug("load_module(): Type is ".$module);
  $self->debug("load_module(): Name is ".$name);
  $self->debug("load_module(): Options are ".Dumper($options));

  $self->debug("load_module(): Attempting to load $name (Ham::Lid::$module)...");
  my $m = 'Ham::Lid::'.$module;
  $self->debug("load_module(): load $m...");
  load $m;

  if($@) {
    $self->error("load_module(): Error loading $name!");
  } else {
    $self->debug("load_module(): Loaded $name.");
    $self->debug("load_module(): Attempting to start $name (Ham::Lid::$module)...");
    if($m->new($self, $name, @{$options}[0])) {
      $self->debug("load_module(): Started $name.");
      $self->debug("load_module() finished.");
      return 1;
    } else {
      $self->error("load_module(): Error starting $name!");
    }
  }

  $self->debug("load_module() finished.");
  return;
}

sub load_modules {
  my ($self) = @_;

  $self->debug("load_modules() called.");
  if(!defined($self->config->{modules})) {
    $self->error("No modules defined in configuration!");
    croak "No modules defined in configuration!";
  }

  foreach my $module (keys %{$self->config->{modules}[0]{module}}) {
    my $type = $self->config->{modules}[0]{module}{$module}{type};
    my $options = $self->config->{modules}[0]{module}{$module}{options};
    $self->debug("Calling load_module() for ".$module."...");
    $self->load_module($type, $module, $options);
  }

  $self->debug("load_modules() finished.");
}

sub start {

  my ($self) = @_;
  $self->debug("[".$self->id."] start() called.");

  $self->debug("[".$self->id."] Calling POE::Kernel->run()...");
  $self->notice("Ready.");
  POE::Kernel->run();

  $self->debug("[".$self->id."] start() finished.");
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
  $self->debug("'".$data->type."' message received from ".$data->source.".");
  switch ($data->type) {
    case "ping" {
      $self->out($self->create_message($data->source, "pong"));
    }
    case "register" {
      $self->register($data->source, $data->message->{name}, $data->message->{type}, $data->message->{manager}, "registered", $data->message->{buffer});
    }
    case "unregister" {
      $self->unregister($data->source);
    }
    case "spawn" {
      $self->spawn($data);
    }
    case "list" {
      $self->list($data);
    }
  }

  $self->debug("[".$self->id."] process() finished.");
}

sub list {
  my ($self, $msg) = @_;

  $self->debug("list() called.");

  $self->debug("list(): Generating registered modules list...");
  my $r;
  foreach my $module (keys %{$self->{register_table}}) {
    $self->debug("list(): ".$module);
    $r->{$module} = $self->{register_table}{$module}{'name'};
  }

  $self->out($self->create_message($msg->source, "list_response", $r));

  $self->debug("list() finished.");
}

sub spawn {

  my ($self, $msg) = @_;

  $self->debug("spawn() called.");

  if($msg->message)
  {
    if($msg->message->{command}) {
      $self->debug("Request to spawn ".$msg->message->{command});
    }
  }

  $self->debug("spawn() finished.");
}

sub register {

  my ($self, $id, $name, $type, $manager, $state, $buffer) = @_;

  $self->debug("[".$self->id."] register() called.");
  $self->debug("[".$self->id."] registration from $id ($type) with name = $name, manager = $manager.");

  $self->{register_table}{$id} = {'id' => $id, 'name' => $name, 'type' => $type, 'manager' => $manager, 'state' => $state, 'buffer' => $buffer};
  $self->out($self->create_message($id, "register_ok"));

  $self->debug("[".$self->id."] Dumping out register_table...");
  print Dumper($self->{register_table});
  $self->debug("[".$self->id."] Dumping out register_table completed.");
  $self->debug("[".$self->id."] register() finished.");
}

sub unregister {

  my ($self, $id) = @_;

  $self->debug("[".$self->id."] unregister() called.");

  delete $self->{register_table}{$id};
  $self->debug("[".$self->id."] Dumping out register_table...");
  print Dumper($self->{register_table});
  $self->{register_table}{$id} = undef;

  $self->debug("[".$self->id."] Dumping out register_table completed.");

  $self->debug("[".$self->id."] unregister() finished.");
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
  # We're the manager, so we have to find the relevant buffer
  my $name = $self->{register_table}{$msg->destination}{name};
  $self->debug("Name is $name");
  $poe_kernel->post($poe_kernel->alias_resolve($name), 'in', $msg);
  $self->debug("[".$self->id."] out() finished.");
}


1;
