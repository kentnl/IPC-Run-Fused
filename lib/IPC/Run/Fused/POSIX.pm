
use strict;
use warnings;

package IPC::Run::Fused::POSIX;
BEGIN {
  $IPC::Run::Fused::POSIX::AUTHORITY = 'cpan:KENTNL';
}
{
  $IPC::Run::Fused::POSIX::VERSION = '0.04000100';
}

use IO::Handle;

# ABSTRACT: Implementation of IPC::Run::Fused for POSIX-ish systems.


sub _fail { goto \&IPC::Run::Fused::_fail }

sub run_fused {
  my ( $read_handle, @params ) = @_;

  my ( $reader, $writer );

  pipe( $reader, $writer ) or _fail('Creating Pipe');

  if ( my $pid = fork() ) {
    $_[0] = $reader;
    return $pid;
  }

  open *STDOUT, '>>&=', $writer->fileno or _fail('Assigning to STDOUT');
  open *STDERR, '>>&=', $writer->fileno or _fail('Assigning to STDERR');

  if ( ref $params[0] and ref $params[0] eq 'CODE' ) {
    $params[0]->();
    exit;
  }
  if ( ref $params[0] and ref $params[0] eq 'SCALAR' ) {
    my $command = ${ $params[0] };
    exec $command or _fail('<<exec command>> failed');
    exit;
  }

  my $program = $params[0];
  exec {$program} @params or _fail('<<exec {program} @argv>> failed');
  exit;
}

1;

__END__

=pod

=head1 NAME

IPC::Run::Fused::POSIX - Implementation of IPC::Run::Fused for POSIX-ish systems.

=head1 VERSION

version 0.04000100

=head1 METHODS

=head2 run_fused

  run_fused( $fh, $executable, @params ) || die "$@";
  run_fused( $fh, \$command_string )     || die "$@";
  run_fused( $fh, sub { .. } )           || die "$@";

  # Recommended

  run_fused( my $fh, $execuable, @params ) || die "$@";

  # Somewhat supported

  run_fused( my $fh, \$command_string ) || die "$@";

$fh will be clobbered like 'open' does, and $cmd, @args will be passed, as-is, through to exec() or system().

$fh will point to an IO::Handle attached to the end of a pipe running back to the called application.

the command will be run in a fork, and stderr and stdout "fused" into a singluar pipe.

B<NOTE:> at present, STDIN's FD is left unchanged, and child processes will inherit parent STDIN's, and will thus block ( somewhere ) waiting for response.

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Kent Fredric.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
