
use strict;
use warnings;

package IPC::Run::Fused::Win32;

use IO::Handle;
use Module::Runtime;

# ABSTRACT: Implementation of IPC::Run::Fused for Win32

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

the command will be run in a fork, and stderr and stdout "fused" into a singluar pipe.

B<NOTE:> at present, STDIN's FD is left unchanged, and child processes will inherit parent STDIN's, and will thus block ( somewhere ) waiting for response.

=cut

sub _fail { goto \&IPC::Run::Fused::_fail }

BEGIN {

  Module::Runtime::require_module('Win32API::File');
  Module::Runtime::require_module('Socket');

  Socket->import();
  Win32API::File->import(qw( GetOsFHandle SetHandleInformation HANDLE_FLAG_INHERIT ));

}

sub _share_handle_win32 {
  my ( $handle, $share ) = @_;
  my $oshandle = GetOsFHandle( $handle );
  SetHandleInformation( $oshandle , HANDLE_FLAG_INHERIT() , $share );
}
sub run_fused {
  my ( $read_handle, @params ) = @_;

  my ( $reader, $writer );

  if ( not ref $params[0] or not ref $params[0] eq 'CODE') {
    _fail("Sorry, run_fused is entirely broken still for anything other than run_fused( handle, sub { } ) on Win32");
  }
  socketpair( $reader, $writer, AF_UNIX, SOCK_STREAM, PF_UNSPEC ),
    and shutdown( $reader, 1 ),
    and shutdown( $writer, 0 ),
    or _fail("creating socketpair");

  #_share_handle_win32(*STDOUT, 0);
  #_share_handle_win32(*STDIN, 0);

  if ( my $pid = fork() ) {
    $_[0] = $reader;
    return $pid;
  }

  close *STDOUT;
  close *STDERR;

  #*STDERR = IO::Handle->new();
  #*STDOUT = IO::Handle->new();
  open *STDOUT, '>>&=', $writer or _fail('Assigning to STDOUT');
  open *STDERR, '>>&=', $writer or _fail('Assigning to STDERR');

  #_share_handle_win32(*STDOUT);
  #_share_handle_win32(*STDERR);

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
