package Ham::Lid;

use 5.012004;
use strict;
use warnings;

require Exporter;
use Moose;
use POE qw( Wheel::Run );
use Data::Dumper;
use Data::GUID;
use Ham::Lid::Debug;
use Ham::Lid::Manager;
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
  __PACKAGE__->notice("Starting up.");
}

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.
has 'manager' => (is => 'rw');

sub new {

  my $class = shift;
  my $g = Data::GUID->new;
  my $self = {
    'version' => $VERSION,
    'id' => $g->as_string
  };

  bless $self, $class;
  $self->debug("new() called.");

  return $self;
}

sub init {

  my ($self) = @_;
  $self->debug("init() called.");

  # Initialise POE
  $self->debug("Creating Ham::Lid::Manager...");
  $self->manager(new Ham::Lid::Manager);

  $self->debug("init() finished.");
}

sub start {

}

1;
