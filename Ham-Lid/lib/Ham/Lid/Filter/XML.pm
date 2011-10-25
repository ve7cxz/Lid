package Ham::Lid::Filter::XML;

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
use Carp;
use XML::Simple;
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

has 'version' => (is => 'rw');
has 'id' => (is => 'rw');
has 'message' => (is => 'rw');

sub new {
  my ($class, $message) = @_;
  my $g = Data::GUID->new;
  my $self = {
    'version' => $VERSION,
    'id' => $g->as_string,
    'message' => $message,
  };

  bless $self, $class;
  $self->debug("new() called.");

  if(!defined($self->message)) {
    $self->error("No message passed.");
    return 0;
  }

  return $self;
  $self->debug("new() finished.");
}

sub encode {
  my ($self) = @_;

  my $x = XML::Simple->new(RootName => 'msg');
  my $msg = eval { return $x->XMLout($self->message); };

  if(!$@) {
    return $msg;
  } else {
    $self->error("Error parsing XML message!");
    return 0;
  }
}

sub decode {
  my ($self) = @_;

  my $x = XML::Simple->new;
  my $msg = eval { return $x->XMLin($self->message); };

  if(!$@) {
    return $msg;
  } else {
    $self->error("Error parsing XML message!");
    return 0;
  }
}

1;
