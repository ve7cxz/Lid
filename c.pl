#!/usr/bin/perl

use strict;
use warnings;

use XML::Simple;

my $xi = XML::Simple->new(ForceArray => 1);
my $x = XML::Simple->new(RootName => 'config');

print $x->XMLout($xi->XMLin('config.xml'));
