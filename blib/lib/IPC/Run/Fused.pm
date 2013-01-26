use strict;
use warnings;

package IPC::Run::Fused;
BEGIN {
  $IPC::Run::Fused::AUTHORITY = 'cpan:KENTNL';
}
{
  $IPC::Run::Fused::VERSION = '0.01028807';
}
use 5.008000;

# ABSTRACT: Capture Stdout/Stderr simultaneously as if it were one stream, painlessly.
#



use POSIX qw();
use IO::Handle;

use Sub::Exporter -setup => { exports => [qw( run_fused )], };

sub _mk_pipe_perl(&) {
  my ( $response_r, $response_w, $fail ) = ( undef, undef, @_ );
  pipe $response_r, $response_w;
  if ( not defined $response_r or not defined $response_w ) {
    return $fail->('perl `pipe` doesn\'t work');
  }
  $response_r->autoflush(1);
  $response_w->autoflush(1);
  if ( not defined $response_r->fileno ) {
    $fail->( 'Fileno not supported on pipe reader', $?, $!, $^E, $@ );
  }
  if ( not defined $response_w->fileno ) {
    $fail->( 'Fileno not supported on pipe writer', $?, $!, $^E, $@ );
  }
  return ( $response_r, $response_w, fileno $response_r, fileno $response_w );
}

sub _mk_pipe_posix(&) {
  my ( $response_r, $response_w, $fail ) = ( undef, undef, @_ );
  ( $response_r, $response_w ) = POSIX::pipe();
  my ( $responder, $writer );
  if ( not defined $response_r or not defined $response_w ) {
    return $fail->( 'posix pipe doesn\'t work', $?, $!, $^E, $@ );
  }
  $responder = IO::Handle->new->fdopen( $response_r, 'r' );
  $writer    = IO::Handle->new->fdopen( $response_w, 'w' );
  if ( not defined $writer ) {
    return $fail->( 'writer not defined', $?, $!, $^E, $@ );
  }
  if ( not defined $responder ) {
    return $fail->( 'responder not defined', $?, $!, $^E, $@ );
  }

  $responder->autoflush(1);
  $writer->autoflush(1);

  return ( $responder, $writer, $response_r, $response_w );
}

sub _run_fork {
  my ( $write_fno, $params, $fail ) = @_;

  # Reopen STDERR and STDOUT to point to the pipe.
  open *STDOUT, '>>&=', $write_fno || $fail->( 'Assigning to STDOUT', $?, $!, $^E, $@ );
  open *STDERR, '>>&=', $write_fno || $fail->( 'Assigning to STDERR', $?, $!, $^E, $@ );

  select *STDERR;
  $|++;
  select *STDOUT;
  $|++;

  my $program = $params->[0];

  if ( ref $program ) {
    exec ${$program} or $fail->( 'Calling process', $?, $!, $^E, $@ );
  }
  else {
    exec {$program} @{$params}
      or $fail->( 'Calling process', $?, $!, $^E, $@ );
  }
  exit    # dead code.
}

sub run_fused {
  my ( $fhx, @rest ) = @_;

  my ( $responder, $writer, $fdr, $fdw ) = _mk_pipe_perl {
    Carp::cluck("Native pipe failed, trying posix ( @_ )");
    return _mk_pipe_posix {
      Carp::confess("Posix pipe failed : @_ ");
    };
  };

  # Return the handle to the user.
  $_[0] = $responder;

  # Run the users app with the new stuff.
  _run_fork(
    $fdw,
    \@rest,
    sub {
      Carp::confess("Fork Failure, @_ ");
    }
  ) if ( not my $pid = fork() );

  return 1;
}

1;

__END__

=pod

=head1 NAME

IPC::Run::Fused - Capture Stdout/Stderr simultaneously as if it were one stream, painlessly.

=head1 VERSION

version 0.01028807

=head1 SYNOPSIS

  use IPC::Run::Fused qw( run_fused );

  run_fused( my $fh, $stderror_filled_program, '--file', $tricky_filename, @moreargs ) || die "Argh $@";
  open my $fh, '>', 'somefile.txt' || die "NOO  $@";

  # Simple implementation of 'tee' like behaviour,
  # sending to stdout and to a file.

  while ( my $line = <$fh> ) {
    print $fh $line;
    print $line;
  }

=head1 DESCRIPTION

Have you ever tried to do essentially the same as you would in bash do to this:

  parentapp <( app 2>&1  )

And found massive road works getting in the way.

Sure, you can aways do this style syntax:

  open my $fh, 'someapp --args foo 2>&1 |';

But thats not very nice, because

=over 4

=item 1. you're relying on a subshell to do that for you

=item 2. you have to manually escape everything

=item 3. you can't use list context.

=back

And none of this is very B<Modern> or B<Nice>

=head1 SIMPLEST THING THAT JUST WORKS

This code is barely tested, its here, because I spent hours griping about how the existing ways suck.

=head1 FEATURES

=over 4

=item 1. No String Interpolation.

Arguments after the first work as if you'd passed them directly to 'system'. You can be as dangerous or as
safe as you want with them. We recommend passing a list, but a string ( as a scalar reference ) should work

But if you're using a string, this modules probably not affording you much.

=item 2. No dicking around with managing multiple file handles yourself.

I looked at L<IPC::Run> L<IPC::Run3> and L<IPC::Open3>, and they all seemed very unfriendly, and none did what I wnted.

=item 3. Non-global filehandles supported by design.

All the competition seem to still have this thing for global file handles and you having to use them. Yuck!.

We have a few global FH's inside our code, but they're only STDERR and STDOUT, at present I don't think I can circumvent that. If I ever can, I'll endeavour to do so =)

=back

=head1 EXPORTED FUNCTIONS

No functions are exported by default, be explicit with what you want.

At this time there is only one, and there are no plans for more.

=head2 run_fused

  run_fused( $fh, $executable, @params ) || die "$@";
  run_fused( $fh, \$command_string ) || die "$@";

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
