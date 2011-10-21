package Ham::Lid::Session;

use 5.012004;
use strict;
use warnings;

require Exporter;
use Moose;
use POE qw( Wheel::Run );
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
has 'buffer_in' => (is => 'rw');
has 'buffer_out' => (is => 'rw');
has 'manager' => (is => 'rw');
has 'heap' => (is => 'rw');

sub new {

  my ($class, $manager, $a) = @_;

  my $g = Data::GUID->new;
  my $self = {
    'version' => $VERSION,
    'id' => $g->as_string
  };

  bless $self, $class;

  if(!defined($manager)) {
    $self->error("No manager passed to session.");
    croak "No manager passed to session.";
  } else {
    $self->manager($manager);
    $self->debug("Manager passed (ID ".$manager->id.")");
  }

  if(!defined($a->{'name'})) {
    $self->error("Missing 'name' argument");
    croak "Missing 'name' argument in ".__PACKAGE__;
  } else {
    $self->name($a->{'name'});
  }

  $self->debug("new() called.");
  $self->debug("ID is ".$self->id);
  $self->init();

  return $self;
}

sub msg {
  my ($self, $msg) = @_;

  $self->debug("msg() called.");

  $self->debug("msg is ".Dumper($msg));
}

sub init {

  my ($self) = @_;
  $self->debug("init() called.");

  # Create buffers to hold data
  $self->buffer_in(Ham::Lid::Buffer->new);
  $self->buffer_out(Ham::Lid::Buffer->new);

  $self->debug("Creating POE::Session...");
  $self->session(POE::Session->create(
    inline_states => {
      _start            => sub { $self->on_start() },
    }
  ));

  $self->buffer_in->register_callback("out", "default", sub { $self->msg($_[0]); } );

  $self->heap->{client}->run("/bin/nc -l -p 1234");

  $self->debug("init() finished.");
}

sub on_start {
  
  my ($self) = @_;

  $_[HEAP]{client} = POE::Component::Child->new(
    debug => 1,
    events => {
      stdout  => sub { my ($stdout, $wheel_id) = @_[ARG0, ARG1]; $self->buffer_in->in($_[1]->{out}); },
      done    => sub { $self->debug("[".$self->id."] Process done.") },
      died    => sub { $self->debug("[".$self->id."] Process died.") },
      error   => sub { $self->debug("[".$self->id."] Process errored (".$_[1]->{error}.")") },
    }
  );
  $self->heap($_[HEAP]);

#  $self->debug("Process started as ".$child->PID);

}

1;
