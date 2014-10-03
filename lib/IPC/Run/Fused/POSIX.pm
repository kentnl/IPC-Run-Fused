use 5.008003;
use strict;
use warnings;

package IPC::Run::Fused::POSIX;

our $VERSION = '1.000001';

# ABSTRACT: Implementation of IPC::Run::Fused for POSIX-ish systems.

# AUTHORITY

use IO::Handle;

=method run_fused

  run_fused( $fh, $executable, @params ) || die "$@";
  run_fused( $fh, \$command_string )     || die "$@";
  run_fused( $fh, sub { .. } )           || die "$@";

  # Recommended

  run_fused( my $fh, $execuable, @params ) || die "$@";

  # Somewhat supported

  run_fused( my $fh, \$command_string ) || die "$@";

$fh will be clobbered like 'open' does, and $cmd, @args will be passed, as-is, through to exec() or system().

$fh will point to an IO::Handle attached to the end of a pipe running back to the called application.

the command will be run in a fork, and C<STDERR> and C<STDOUT> "fused" into a singular pipe.

B<NOTE:> at present, C<STDIN>'s FD is left unchanged, and child processes will inherit parent C<STDIN>'s, and will thus block ( somewhere ) waiting for response.

=cut

use Exporter qw(import);
use IPC::Run::Fused qw( _fail );

our @EXPORT_OK = qw( run_fused );

sub run_fused {    ## no critic ( Subroutines::RequireArgUnpacking )

  my ( $read_handle, @params ) = ( \shift @_, @_ );

  my ( $reader, $writer );

  pipe $reader, $writer or _fail('Creating Pipe');

  if ( my $pid = fork ) {
    ${$read_handle} = $reader;
    return $pid;
  }

  open *STDOUT, '>>&=', $writer->fileno or _fail('Assigning to STDOUT');
  open *STDERR, '>>&=', $writer->fileno or _fail('Assigning to STDERR');

  if ( ref $params[0] and 'CODE' eq ref $params[0] ) {
    $params[0]->();
    exit;
  }
  if ( ref $params[0] and 'SCALAR' eq ref $params[0] ) {
    my $command = ${ $params[0] };
    exec $command or _fail('<<exec command>> failed');
    exit;
  }

  my $program = $params[0];
  ## no critic (ValuesAndExpressions::RequireInterpolationOfMetachars)
  exec {$program} @params or _fail('<<exec {program} @argv>> failed');
  exit;
}

1;
