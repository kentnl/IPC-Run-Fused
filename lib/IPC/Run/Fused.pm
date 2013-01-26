use strict;
use warnings;

package IPC::Run::Fused;
BEGIN {
  $IPC::Run::Fused::AUTHORITY = 'cpan:KENTNL';
}
{
  $IPC::Run::Fused::VERSION = '0.02000000';
}
use 5.008000;

# ABSTRACT: Capture Stdout/Stderr simultaneously as if it were one stream, painlessly.
#



use IO::Pipe;
use IO::Handle;

use Sub::Exporter -setup => { exports => [qw( run_fused )], };

sub _run_fork {
  my ( $pipe, $params, $fail ) = @_;

  my $writer = $pipe->writer;

  # Reopen STDERR and STDOUT to point to the pipe.
  open *STDOUT, '>>&=', $writer->fileno || $fail->( 'Assigning to STDOUT', $?, $!, $^E, $@ );
  open *STDERR, '>>&=', $writer->fileno || $fail->( 'Assigning to STDERR', $?, $!, $^E, $@ );

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

  my $pipe = IO::Pipe->new();

  my $pid = fork();
  if ( not $pid ) {

    _run_fork(
      $pipe,
      \@rest,
      sub {
        Carp::confess("Fork Failure, @_ ");
      }
    );
    exit;
  }

  $_[0] = $pipe->reader;

  return 1;
}

1;

__END__

=pod

=head1 NAME

IPC::Run::Fused - Capture Stdout/Stderr simultaneously as if it were one stream, painlessly.

=head1 VERSION

version 0.02000000

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
