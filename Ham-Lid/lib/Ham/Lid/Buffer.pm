package Ham::Lid::Buffer;

use 5.012004;
use strict;
use warnings;

require Exporter;
use Moose;
use POE qw( Wheel::Run );
use Data::Dumper;
use Data::GUID;
use Ham::Lid::Debug;
use Ham::Lid::Message;
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
has 'buffer' => (is => 'rw');
has 'read_position' => (is => 'rw');
has 'write_position' => (is => 'rw');

sub new {

  my $class = shift;
  my $a = shift;

  my $g = Data::GUID->new;
  my $self = {
    'version' => $VERSION,
    'id' => $g->as_string
  };

  $self->{buffer} = [];
  $self->{read_position} = 0;
  $self->{write_position} = 0;

  bless $self, $class;

  $self->debug("new() called.");
  $self->debug("ID is ".$self->id);

  return $self;
}

sub in
{
	my ($self, $data) = @_;

	$self->{buffer}[$self->{write_position}] = $data;

	$self->debug($self->id." has data written at position ".$self->write_position);
	$self->debug($self->id." data is ".$data);
	$self->{write_position}++;

	$self->flush;

	return 1;
}

sub flush
{
	my ($self) = @_;

	if($self->read_position eq $self->write_position)
	{
		$self->debug("[".__PACKAGE__."] "."buffer ".$self->id." is empty");
		return 0;
	}

	if($self->has_callbacks("out") && $self->read_position < $self->write_position)
	{
		while($self->has_callbacks("out") && $self->read_position < $self->write_position)
		{
			my $buffer = $self->{buffer}[$self->read_position];
			$self->debug("[".__PACKAGE__."] "."Read data from buffer ".$self->id." at position ".$self->read_position);
			my $data = delete $self->{buffer}[$self->read_position];
			my $datapos = $self->read_position;
			$self->{read_position}++;

			if(!$self->do_callbacks("out", $buffer))
			{
				$self->debug($self->id." no longer has any callbacks. Resetting position.");
        $self->{read_position}--;
			  $self->{buffer}[$self->read_position] = $buffer;
			}
		}
		$self->debug($self->id." now empty");
		return 1;
	}
	else
	{
		$self->debug("[".__PACKAGE__."] "."No callbacks for ".$self->id);
		return 0;
	}
}

1;
