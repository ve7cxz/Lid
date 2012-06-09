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
has 'name' => (is => 'rw');
has 'buffer' => (is => 'rw');
has 'register_table' => (is => 'rw');
has 'config' => (is => 'rw');
has 'config_location' => (is => 'rw');

sub new {

  my $class = shift;
  my $g = Data::GUID->new;
  my $self = {
    'version' => $VERSION,
    'id' => $g->as_string,
    'sessions' => {},
    'register_table' => {},
    'name' => 'manager',
  };

  bless $self, $class;
  $self->debug("new() called.");

  # Create input buffer
#  $self->buffer(new Ham::Lid::Buffer);
#  $self->buffer->register_callback("out", "default", sub { $self->input($_[0]); } );

  $self->load_config;
  $self->save_config;

  $self->session(POE::Session->create(
    inline_states => {
      _start => sub {
        $self->debug("_start triggered");
        $_[KERNEL]->alias_set("manager");
        $self->load_modules;
        $_[KERNEL]->yield("tick");
      },
      tick => sub {
        $_[KERNEL]->delay(tick => 1);
      },
      in   => sub {
 #       $self->buffer->in($_[ARG0]);
        $self->input($_[ARG0]);
      },
    }
  ));

  # Start console
  #my $console = new Ham::Lid::Console($self);
  #new Ham::Lid::Daemon($self, "daemon_4321");
  #new Ham::Lid::Auth($self, "authenticator");
  #new Ham::Lid::Console($self, "console");
  #new Ham::Lid::Example($self, "example");
  #new Ham::Lid::DXCluster($self, "dxcluster", "localhost", "7300", "M0VKG");

  $self->start();
  $self->debug("new() finished.");
  return $self;
}

sub load_config {
  my ($self) = @_;

  $self->debug("load_config() called.");
  my $x = XML::Simple->new(ForceArray => 1);

  my $l = ['/etc/lid/config.xml', '~/.lid/config.xml', './config.xml'];

  my $loaded = 0;
  foreach my $location (@{$l}) {
    $self->debug("Attempting to load configuration file from ".$location."...");
    if(-f $location) {
      $self->debug("Found ".$location);
      $self->config_location($location);
      $self->config($x->XMLin($location));
      if($@) {
        $self->error("Error loading ".$location."!");
      } else {
        $self->debug("Successfully loaded config from ".$location.".");
        $self->debug("load_config() finished.");
        $loaded = 1;
      }
    }
  }

  if($loaded) {
    return 1;
  } else {
    $self->error("Couldn't find a working configuration file!");
    croak "Couldn't find a working configuration file!\n";
  }

}

sub save_config {
  my ($self) = @_;

  $self->debug("save_config() called.");
  my $x = XML::Simple->new();#ForceArray => 1, KeyAttr => { filters => 'filter' });

  my $xc = $x->XMLout($self->config);

  open CONFIG, ">", "config_saved.xml";
  print CONFIG $xc;
  close CONFIG;
}

sub get_config_modules {
  my ($self) = @_;

  $self->debug("get_config_modules() called.");

  my @modules;
  while (my ($key, $value) = each (%{$self->config->{module}})) {
    $self->debug("get_config_modules(): $key.");
    push @modules, $key;
  }

  $self->debug("get_config_modules() finished.");

  return @modules;
}

sub get_config_module_instances {
  my ($self, $module) = @_;

  $self->debug("get_config_module_instances() called.");

  my @instances;
  while ( my ($key, $value) = each (%{$self->config->{module}{$module}{instance}})) {
    $self->debug("get_config_module_instances(): $key.");
    push @instances, $key;
  }

  $self->debug("get_config_module_instances() finished.");

  return @instances;
}

sub get_config_module_instance {
  my ($self, $module, $name) = @_;

  $self->debug("get_config_module_instance() called.");

  $self->debug("get_config_module_instance() finished.");

  return $self->config->{module}{$module}{instance}{$name};
}

sub get_config_module_global {
  my ($self, $module) = @_;

  $self->debug("get_config_module_global() called.");

  $self->debug("get_config_module_global() finished.");

  return $self->config->{module}{$module};
}

sub load_instance {
  my ($self, $module, $name, $config, $global_config) = @_;

  $self->debug("load_instance() called.");
  $self->debug("load_instance(): Loading ".$name."...");
  $self->debug("load_instance(): Type is ".$module);
  $self->debug("load_instance(): Name is ".$name);
  $self->debug("load_instance(): Is this instance enabled: ".$config->{enabled});

  if($config->{enabled} eq "yes") {
    $self->debug("load_instance(): Attempting to load $module (Ham::Lid::$module)...");
    my $m = 'Ham::Lid::'.$module;
    $self->debug("load_instance(): load $m...");
    load $m;
  
    if($@) {
      $self->error("load_instance(): Error loading $module!");
    } else {
      $self->debug("load_instance(): Loaded $module.");
      $self->debug("load_instance(): Attempting to start $name (Ham::Lid::$module)...");
      if($m->new($self, $name, $config, $global_config)) {
        $self->debug("load_instance(): Started $name.");
        $self->debug("load_instance() finished.");
        return 1;
      } else {
        $self->error("load_instance(): Error starting $name!");
      }
    }
  } else {
    $self->debug("load_instance(): Instance is not enabled.");
  }

  $self->debug("load_instance() finished.");
  return;
}

sub load_filters {
}

sub load_modules {
  my ($self) = @_;

  $self->debug("load_modules() called.");

  $self->debug("Loading modules...");
  # Look for module definitions
  foreach my $module ($self->get_config_modules) {
    $self->debug("Found configuration for ".$module.".");
    # Look for module instance definitions
    foreach my $instance ($self->get_config_module_instances($module)) {
      $self->debug("Found instance with name '".$instance."'...");
      # Look for module instance configuration
      my $config = $self->get_config_module_instance($module, $instance);
      my $global_config = $self->get_config_module_global($module);
      $self->load_instance($module, $instance, $config, $global_config);
    }
  }
#  $poe_kernel->post($poe_kernel->alias_resolve('dxcluster_gb7mbc'), 'shutdown');

  $self->debug("load_modules() finished.");
}

sub start {

  my ($self) = @_;
  $self->debug("start() called.");

  $self->debug("Calling POE::Kernel->run()...");
  $self->notice("Ready.");
  POE::Kernel->run();

  $self->debug("start() finished.");
}

sub input {
  my ($self, $data) = @_;
  $self->debug("input() called.");
  if(ref $data ne "Ham::Lid::Message")
  {
    $self->error("Message is not of type Ham::Lid::Message!");
    return 0;
  }

  $self->debug("I am ".$self->name.", message is for ".$data->destination);

  if($data->destination eq $self->name) {
    $self->debug("Message is for me.");
    $self->process($data);
  } else {
    $self->debug("Message is not for me.");
    $self->out($data);
  }
  $self->debug("input() finished.");
}

sub process {

  my ($self, $data) = @_;

  $self->debug("process() called.");
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

  $self->debug("process() finished.");
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

sub register {

  my ($self, $id, $name, $type, $manager, $state, $buffer) = @_;

  $self->debug("register() called.");
  $self->debug("registration from $id ($type) with name = $name, manager = $manager.");

  $self->{register_table}{$name} = {'id' => $id, 'name' => $name, 'type' => $type, 'manager' => $manager, 'state' => $state, 'buffer' => $buffer};
  $self->out($self->create_message($name, "register_ok"));

  #$self->debug("Dumping out register_table...");
  #print Dumper($self->{register_table});
  #$self->debug("Dumping out register_table completed.");
  $self->debug("register() finished.");
}

sub unregister {

  my ($self, $id) = @_;

  $self->debug("unregister() called.");

  delete $self->{register_table}{$id};
  $self->debug("Dumping out register_table...");
  print Dumper($self->{register_table});
  $self->{register_table}{$id} = undef;

  $self->debug("Dumping out register_table completed.");

  $self->debug("unregister() finished.");
}

sub create_message {
  my ($self, $destination, $type, $data) = @_;

  my $m = new Ham::Lid::Message({'message' => $data, 'type' => $type, 'source' => 'manager', 'destination' => $destination});

  return $m;
}

sub out {
  my ($self, $msg) = @_;

  $self->debug("ID    : ".$msg->id);
  $self->debug("SOURCE: ".$msg->source);
  $self->debug("DEST  : ".$msg->destination);
  $self->debug("TYPE  : ".$msg->type);

  $self->debug("out() called.");
  $self->debug("Sending message to ".$msg->destination." of type ".$msg->type.".");
  # We're the manager, so we have to find the relevant buffer
#  my $name = $self->{register_table}{$msg->destination}{name};
#  $self->debug("Name is $name");
  $poe_kernel->post($poe_kernel->alias_resolve($msg->destination), 'in', $msg);
  $self->debug("out() finished.");
}


1;
