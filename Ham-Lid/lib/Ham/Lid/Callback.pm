package Ham::Lid::Callback;

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
	register_callback
  unregister_callback
  do_callbacks
  has_callbacks
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

sub register_callback
{
	my ($self, $callback_name, $callback_alias, $callback_ref) = @_;

	if(!$self)
	{
		$self->error("Callback hash does not exist");
		return 0;
	}

	if(ref $callback_ref ne "CODE")
	{
		$self->error("Callback ref ".$callback_alias." for ".$callback_name." is not a CODE ref");
		return 0;
	}

	$self->debug("Registering callback for ".$callback_name." with alias ".$callback_alias);

	if(defined($self->{callbacks}{$callback_name}{$callback_alias}))
	{
		$self->error("Callback ".$callback_alias." is already defined for ".$callback_name);
		return 0;
	}
	else
	{
		$self->{callbacks}{$callback_name}{$callback_alias} = $callback_ref;
		$self->debug("Callback ".$callback_alias." now defined for ".$callback_name);
		return 1;
	}
}

sub unregister_callback
{
	my ($self, $callback_name, $callback_alias) = @_;

	$self->debug("Unregistering callback for ".$callback_name." with alias ".$callback_alias);

	if(defined($self->{callbacks}{$callback_name}{$callback_alias}))
	{
		delete $self->{callbacks}{$callback_name}{$callback_alias};
		$self->debug("Callback ".$callback_alias." has been unregistered for ".$callback_name);
		return 1;
	}
	else
	{
		$self->error("Callback ".$callback_alias." does not exist for ".$callback_name);
		return 0;
	}
}

sub do_callbacks
{
	my ($self, $callback_name, @args) = @_;

	$self->debug("Doing callbacks for ".$callback_name);

	if(!defined($self->{callbacks}{$callback_name}))
	{
		$self->debug("No callbacks for ".$callback_name);
		return 1;
	}
	else
	{
		foreach my $cb (keys %{$self->{callbacks}{$callback_name}})
		{
			$self->debug("Executing callback for ".$callback_name.": ".$cb);

			eval { $self->{callbacks}{$callback_name}{$cb}(@args) };

			if($@)
			{
				$self->debug("Callback is stale... removing");
				delete $self->{callbacks}{$callback_name}{$cb};
			}
		}
	}

	$self->debug("Finished callbacks for ".$callback_name);
	return 1;
}

sub has_callbacks
{
	my ($self, $callback_name) = @_;

	unless(keys %{$self->{callbacks}{$callback_name}})
	{
		return 0;
	}
	else
	{
		return 1;
	}
}

1;
