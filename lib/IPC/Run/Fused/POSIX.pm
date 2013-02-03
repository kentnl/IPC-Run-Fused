
use strict;
use warnings;

package IPC::Run::Fused::POSIX;
BEGIN {
  $IPC::Run::Fused::POSIX::AUTHORITY = 'cpan:KENTNL';
}
{
  $IPC::Run::Fused::POSIX::VERSION = '0.03000000';
}

use IO::Pipe;

sub run_fused {
  my ( $read_handle, @params ) = @_;

  my ( $reader, $writer );

  pipe( $reader, $writer ) or _fail('Creating Pipe');

  if ( my $pid = fork() ) {
    open $_[0], '<&=', $reader->fileno or _fail('Assigning Read Handle');
    $_[0]->autoflush(1);
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

IPC::Run::Fused::POSIX

=head1 VERSION

version 0.03000000

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Kent Fredric.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
