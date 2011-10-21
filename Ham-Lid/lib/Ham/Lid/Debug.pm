package Ham::Lid::Debug;

use 5.012004;
use strict;
use warnings;

require Exporter;
use Moose;
use POE qw( Wheel::Run );
use Data::Dumper;
use Term::ANSIColor;

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
	debug error warning notice
);

our $VERSION = '0.01';

sub debug {
  
  my ($self, $msg) = @_;

  open (DEBUG, '>>debug.log');
  print color 'blue';
  print "DEBUG   ";
  print color 'reset';
  print ": (";
  print color 'magenta';
  if(ref($self)) {
    print ref $self;
    print DEBUG ref $self;
  } else {
    print $self;
    print DEBUG $self;
  }
  print color 'reset';
  print "): ".$msg."\n";
  print DEBUG " ".$msg."\n";
  close (DEBUG);

}

sub error {
  
  my ($self, $msg) = @_;

  print color 'red';
  print "ERROR   ";
  print color 'reset';
  print ": (";
  print color 'magenta';
  if(ref($self)) {
    print ref $self;
  } else {
    print $self;
  }
  print color 'reset';
  print "): ".$msg."\n";

}

sub warning {
  
  my ($self, $msg) = @_;

  print color 'yellow';
  print "WARNING ";
  print color 'reset';
  print ": (";
  print color 'magenta';
  if(ref($self)) {
    print ref $self;
  } else {
    print $self;
  }
  print color 'reset';
  print "): ".$msg."\n";

}

sub notice {
  
  my ($self, $msg) = @_;

  print color 'green';
  print "NOTICE  ";
  print color 'reset';
  print ": (";
  print color 'magenta';
  if(ref($self)) {
    print ref $self;
  } else {
    print $self;
  }
  print color 'reset';
  print "): ".$msg."\n";

}

1;
