
use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  DISTNAME  => 'IPC-Run-Fused',
  NAME      => 'IPC::Run::Fused',
  AUTHOR    => "Kent\ Fredric\ \<kentnl\@cpan\.org\>",
  ABSTRACT  => "Capture\ Stdout\/Stderr\ simultaneously\ as\ if\ it\ were\ one\ stream\,\ painlessly\.",
  VERSION   => '0.01001607',
  EXE_FILES => [ qw() ],
  (eval { ExtUtils::MakeMaker->VERSION(6.31) } ? (LICENSE => 'perl') : ()),
  PREREQ_PM    => {
    "Test::More" => '0',
    "POSIX" => '0',
    "FindBin" => '0',
    "IO::Handle" => '0',
    "Sub::Exporter" => '0.982',
  },
  test => {TESTS => 't/*.t'}
);

