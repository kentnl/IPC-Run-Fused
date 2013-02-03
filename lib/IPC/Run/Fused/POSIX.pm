
use strict;
use warnings;

package IPC::Run::Fused::POSIX;

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
