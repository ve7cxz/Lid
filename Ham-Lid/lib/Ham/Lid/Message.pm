package Ham::Lid::Message;

use 5.012004;
use strict;
use warnings;

require Exporter;
use Moose;
use POE qw( Wheel::Run );
use Data::Dumper;
use Data::GUID;
use Ham::Lid::Debug;
use Carp;
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
has 'id' => (is => 'rw');
has 'source' => (is => 'rw');
has 'destination' => (is => 'rw');
has 'message' => (is => 'rw');
has 'type' => (is => 'rw');
has 'timestamp' => (is => 'rw');

sub new {

  my $class = shift;
  my $a = shift;

  my $g = Data::GUID->new;
  my $self = {
    'version' => $VERSION,
    'id' => $g->as_string,
  };

  bless $self, $class;

  $self->debug("new() called.");

  if(defined($a->{message})) {
    $self->message($a->{message});
  }

  if(defined($a->{source})) {
    $self->source($a->{source});
  } else {
    $self->warning("Missing 'source' argument.");
    $self->source("UNKNOWN");
  }

  if(defined($a->{type})) {
    $self->type($a->{type});
  } else {
    $self->warning("Missing 'type' argument.");
    $self->type("UNKNOWN");
  }

  if(defined($a->{destination})) {
    $self->destination($a->{destination});
  } else {
    $self->warning("Missing 'destination' argument.");
    $self->destination("UNKNOWN");
  }

  my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
	$year = $year + 1900;
	$hour = sprintf("%02d", $hour);
	$min = sprintf("%02d", $min);
	$sec = sprintf("%02d", $sec);
	$mday = sprintf("%02d", $mday);
	$mon = sprintf("%02d", $mon);

	$self->timestamp($year."-".$mon."-".$mday." ".$hour.":".$min.":".$sec);

  $self->debug("Returning message.");

	return $self;
}

1;
