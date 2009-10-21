#!/usr/bin/perl
use strict;
use warnings;

for my $m ( 0 .. 5 ) {
  print "<<$m>>\n";
  for ( 0 .. 10 ) {
    print {*STDERR} "w$_";
  }
  print {*STDERR} "\n";
  for ( 0 .. 10 ) {
    print {*STDOUT} "p$_";
  }
  print {*STDOUT} "\n";
}
