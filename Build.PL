
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "File::Find" => 0,
    "File::Temp" => 0,
    "FindBin" => 0,
    "Module::Build" => "0.4003",
    "Test::More" => "0.98"
  },
  "configure_requires" => {
    "Module::Build" => "0.4003"
  },
  "dist_abstract" => "Capture Stdout/Stderr simultaneously as if it were one stream, painlessly.",
  "dist_author" => [
    "Kent Fredric <kentnl\@cpan.org>"
  ],
  "dist_name" => "IPC-Run-Fused",
  "dist_version" => "0.01028807",
  "license" => "perl",
  "module_name" => "IPC::Run::Fused",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "IO::Handle" => 0,
    "POSIX" => 0,
    "Sub::Exporter" => "0.982",
    "perl" => "v5.8.3",
    "strict" => 0,
    "warnings" => 0
  },
  "script_files" => []
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
