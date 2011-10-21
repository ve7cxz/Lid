package Ham::Lid::Filter;

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
has 'method' => (is => 'rw');

sub new {
  my ($class, $method, $message) = @_;
  my $g = Data::GUID->new;
  my $self = {
    'version' => $VERSION,
    'id' => $g->as_string,
    'method' => $method,
    'message' => $message,
  };

  bless $self, $class;
  $self->debug("new() called.");

  if(!defined($self->message)) {
    $self->error("No message passed.");
    return;
  }

  if(!defined($self->method)) {
    $self->error("No method passed.");
    return;
  }

  $self->debug("new() finished.");
  return $self;
} 

sub encode {
  my ($self) = @_;

  $self->debug("encode() called.");
  #my $module = "Ham::Lid::Filter::".$method;
  use Ham::Lid::Filter::XML;
  my $e = Ham::Lid::Filter::XML->new($self->message);
  #my $e = eval { require $module; print Dumper($module->encode($message)); };
  $self->debug("encode() finished.");

  return $e->encode;
}

sub decode {
  my ($self) = @_;

  $self->debug("decode() called.");
  #my $module = "Ham::Lid::Filter::".$method;
  use Ham::Lid::Filter::XML;
  my $f = Ham::Lid::Filter::XML->new($self->message);
  #my $d = eval { require $module; return $module->decode($message); };
  my $d = $f->decode();

  if($@) {
    $self->error("Error decoding message!");
    $self->debug("decode() finished.");
    return 0;
  } else {
    my $m = new Ham::Lid::Message({'message' => $d->{message}, 'source' => $d->{source}, 'destination' => $d->{destination}, 'type' => $d->{type}});
    $self->debug("decode() finished.");
    return $m;
  }

}

1;
