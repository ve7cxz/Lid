package Ham::Lid::DXCluster::Filter;

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
has 'filter' => (is => 'rw');
has 'message' => (is => 'rw');
has 'current_field' => (is => 'rw');
has 'current_field_value' => (is => 'rw');

sub new {
  my ($class, $filter) = @_;
  my $g = Data::GUID->new;
  my $self = {
    'version' => $VERSION,
    'id' => $g->as_string,
    'filter' => $filter,
  };

  bless $self, $class;
  $self->debug("new() called.");

  if(!defined($self->filter)) {
    $self->error("No filter passed.");
    return;
  }

  $self->debug("new() finished.");
  return $self;
} 

sub process {
  my ($self, $msg) = @_;

  $self->debug("[".$self->id."] process() called.");
  $self->message($msg);

  my $filter = $self->filter;
  my $r = $self->filter_msg($filter);
  $self->debug("[".$self->id."] process(): Result is $r.");
  $self->debug("[".$self->id."] process() finished.");
}

sub filter_msg {
  my ($self, $hash) = @_;

  keys(%$hash);

  $self->debug("[".$self->id."] filter_msg() called.");
  $self->debug("[".$self->id."] filter_msg(): Input hash coming up!");

  my $msg = $self->message;

  $self->debug("[".$self->id."] filter_msg(): iterating...");
  while ( my ($key, $value) = each %$hash ) {
    $self->debug("[".$self->id."] filter_msg(): key: $key, value: $value");
    switch ($key) {
      case "boolean" {
        $self->debug("[".$self->id."] filter_msg(): found boolean...");
        my @bs;
        my $bbr;

        if(@$value gt 1)
        {
          $self->debug("[".$self->id."] filter_msg(): boolean: multiple boolean statements found.");
          my @bs;
          foreach my $b (@$value) {
            my $type = $b->{type};
            $self->debug("[".$self->id."] filter_msg(): boolean: type is $type.");
            my @br = $self->filter_msg($b);
            my $call = "bool_".$type;
            my $bbr = $self->$call(@br);
            push @bs, $bbr;
          }
          return @bs;
        }
        else
        {
          $self->debug("[".$self->id."] filter_msg(): boolean: single statement found.");
          my $type = @$value[0]->{type};
          $self->debug("[".$self->id."] filter_msg(): boolean: type is $type.");
          my @br = $self->filter_msg(@$value[0]);
          my $call = "bool_".$type;
          my $bbr = $self->$call(@br);
          return $bbr;
        }
      }
      case "field" {
        $self->debug("[".$self->id."] filter_msg(): found field...");
        my @fs;
        while ( my ($fkey, $fvalue) = each %$value ) {
          $self->current_field($fkey);
          $self->current_field_value($msg->{$fkey});
          my $fr = $self->filter_msg($fvalue);
          push @fs, $fr;
        }
        return @fs;
      }
      case "test" {
        $self->debug("[".$self->id."] filter_msg(): found test...");
        my @ts;
        foreach my $t (@$value) {
          my $call = "test_".$t->{type};
          $self->debug("[".$self->id."] filter_msg(): test: Testing ".$self->current_field_value." against ".$t->{content}." with ".$t->{type}."...");
          my $tr = $self->$call($self->current_field_value, $t->{content});
          $self->debug("[".$self->id."] filter_msg(): test: Result is $tr.");
          push @ts, $tr;
        }
        return @ts;
      }
    }
  }

}

sub bool_or {
  my ($self, @rs) = @_;

  foreach my $r (@rs) {
    if($r eq 1) {
      return 1;
    }
  }

  return 0;
}

sub bool_and {
  my ($self, @rs) = @_;

  my $retr = 0;
  foreach my $r (@rs) {
    if($r eq 1) {
      $retr = 1;
    } else {
       return 0;
    }
  }

  return $retr;
}
    
sub test_starts {
  my ($self, $check, $value) = @_;

  if($check =~ m/^$value/) {
    return 1;
  } else {
    return 0;
  }
}

sub test_equals {
  my ($self, $check, $value) = @_;

  if($value eq $check) {
    return 1;
  } else {
    return 0;
  }
}

sub test_ends {
  my ($self, $check, $value) = @_;

  if($check =~ m/$value$/) {
    return 1;
  } else {
    return 0;
  }
}

1;
