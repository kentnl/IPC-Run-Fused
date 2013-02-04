
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

  run_fused( my $fh, $executable, @params ) || die "$@";

  # Somewhat supported

  run_fused( my $fh, \$command_string ) || die "$@";

$fh will be clobbered like 'open' does, and $cmd, @args will be passed, as-is, through to exec() or system().

$fh will point to an IO::Handle attached to the end of a pipe running back to the called application.

the command will be run in a fork, and stderr and stdout "fused" into a singluar pipe.

B<NOTE:> at present, STDIN's FD is left unchanged, and child processes will inherit parent STDIN's, and will thus block ( somewhere ) waiting for response.

=cut

sub _fail { goto \&IPC::Run::Fused::_fail }

BEGIN {

  Module::Runtime::require_module('Socket');

  Socket->import();

}

sub run_fused {
  my ( $read_handle, @params ) = @_;
  if ( ref $params[0] and ref $params[0] eq 'CODE') {
      goto \&_run_fused_coderef;
  }
  goto \&_run_fused_job;
}

sub _run_fused_job {
  my ( $read_handle, @params ) = @_;

  my $config = _run_fused_jobdecode( @params );

  Module::Runtime::require_module('File::Which');

  $config->{which} = File::Which::which($config->{executable});

  local $IPC::Run::Fused::FAIL_CONTEXT{which} = $config->{which};
  local $IPC::Run::Fused::FAIL_CONTEXT{executable} = $config->{executable};
  local $IPC::Run::Fused::FAIL_CONTEXT{command} = $config->{command};

  if ( not $config->{which} ){
    _fail('Failed to resolve executable to path');
  }

  Module::Runtime::require_module('Win32::Job');

  pipe( $_[0], my $writer );

  if ( my $pid = fork() ) {
    return $pid;
  }

  my $job = Win32::Job->new();
  $job->spawn(
    $config->{which},
    $config->{command},
    {
      stdout => $writer,
      stderr => $writer,
    }
  ) or _fail('Could not spawn job');
  my $result = $job->run( -1 , 0 );
  if ( not $result )  {
    my $status  = $job->status();
    if( exists $status->{exitcode } and $status->{exitcode} == 293 ){
      _fail('Process used more than allotted time');
    }
    _fail('Child process terminated with exit code' . $status->{exitcode} )
  }
  exit;
}

sub _run_fused_jobdecode {
  my ( @params ) = @_;

  if ( ref $params[0] and ref $params[0] eq 'SCALAR' ) {
    my $command = ${ $params[0] };
    $command =~ s/^\s*//;
    return {
      command => $command,
      executable => _win32_command_find_invocant( $command ),
    };
  }
  return {
    executable => $params[0],
    command    => _win32_escape_command( @params ),
  };
}


sub _run_fused_coderef {
  my ( $read_handle, $code ) = @_;
  my ( $reader, $writer );

  socketpair( $reader, $writer, AF_UNIX, SOCK_STREAM, PF_UNSPEC ),
    and shutdown( $reader, 1 ),
    and shutdown( $writer, 0 ),
    or _fail("creating socketpair");

  if ( my $pid = fork() ) {
    $_[0] = $reader;
    return $pid;
  }

  close *STDERR;
  close *STDOUT;
  open *STDOUT, '>>&=', $writer or _fail('Assigning to STDOUT');
  open *STDERR, '>>&=', $writer or _fail('Assigning to STDERR');
  $code->();
  exit;

}

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
