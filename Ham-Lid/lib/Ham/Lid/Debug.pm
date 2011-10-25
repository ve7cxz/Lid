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
  print STDERR color 'blue';
  print STDERR "DEBUG   ";
  print STDERR color 'reset';
  print STDERR ": (";
  print STDERR color 'magenta';
  if(ref($self)) {
    print STDERR ref $self;
    print DEBUG ref $self;
  } else {
    print STDERR $self;
    print DEBUG $self;
  }
  print STDERR color 'reset';
  print STDERR "): ".$msg."\n";
  print DEBUG " ".$msg."\n";
  close (DEBUG);

}

sub error {
  
  my ($self, $msg) = @_;

  open (ERROR, '>>debug.log');
  print STDERR color 'red';
  print STDERR "ERROR   ";
  print STDERR color 'reset';
  print STDERR ": (";
  print STDERR color 'magenta';
  if(ref($self)) {
    print STDERR ref $self;
    print ERROR ref $self;
  } else {
    print STDERR $self;
    print ERROR $self;
  }
  print STDERR color 'reset';
  print STDERR "): ".$msg."\n";
  print ERROR " ".$msg."\n";
  close(ERROR);
}

sub warning {
  
  my ($self, $msg) = @_;

  open (WARNING, '>>debug.log');
  print STDERR color 'yellow';
  print STDERR "WARNING ";
  print STDERR color 'reset';
  print STDERR ": (";
  print STDERR color 'magenta';
  if(ref($self)) {
    print STDERR ref $self;
    print WARNING ref $self;
  } else {
    print STDERR $self;
    print WARNING $self;
  }
  print STDERR color 'reset';
  print STDERR "): ".$msg."\n";
  print WARNING " ".$msg."\n";
  close(WARNING);

}

sub notice {
  
  my ($self, $msg) = @_;

  open (NOTICE, '>>debug.log');
  print STDERR color 'green';
  print STDERR "NOTICE  ";
  print STDERR color 'reset';
  print STDERR ": (";
  print STDERR color 'magenta';
  if(ref($self)) {
    print STDERR ref $self;
    print NOTICE ref $self;
  } else {
    print STDERR $self;
    print NOTICE $self;
  }
  print STDERR color 'reset';
  print STDERR "): ".$msg."\n";
  print NOTICE " ".$msg."\n";
  close(NOTICE);

}

1;
