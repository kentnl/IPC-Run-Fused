
use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
  module_name   => 'IPC::Run::Fused',
  license       => 'perl',
  dist_abstract => "Capture\ Stdout\/Stderr\ simultaneously\ as\ if\ it\ were\ one\ stream\,\ painlessly\.",
  dist_name     => "IPC\-Run\-Fused",
  dist_author   => [
"Kent\ Fredric\ \<kentnl\@cpan\.org\>",
  ],
  requires      => {
    "Test::More" => '0',
    "POSIX" => '0',
    "FindBin" => '0',
    "IO::Handle" => '0',
    "Sub::Exporter" => '0.982',
    "Time::HiRes" => '0',
  },
  script_files => [ qw() ],
);

$build->create_build_script;
