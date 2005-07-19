package Sys::RunUntil;

# Set version
# Make sure we're strict

$VERSION = '0.02';
use strict;

# Satisfy -require-

1;

#---------------------------------------------------------------------------
#
# Standard Perl functionality
#
#---------------------------------------------------------------------------
# import
#
# Called during execution of "use"
#
#  IN: 1 class
#      2 runtime of script

sub import {

# Obtain the initial run time
# Die now if nothing to check

    my $runtime = $_[1];
    die "Must specify a time until which the script should run\n"
     unless defined $runtime;

# Initialize CPU time flag if wallclock identifier given
# Set CPU flag if so specified
# Die now if invalid characters found

    my $cpu = ($runtime =~ s#[cC]##);
    $cpu = undef if $runtime =~ s#[wW]##;
    die "Unrecognizable runtime specified: $runtime\n"
     unless $runtime =~ m#^[sSmMhHdD\d]+$#;

# Convert seconds into seconds
# Convert minutes into seconds
# Convert hours into seconds
# Convert days into seconds

    my $seconds = 0;
    $seconds += $1           if $runtime =~ m#(\d+)[sS]?#;
    $seconds += (60 * $1)    if $runtime =~ m#(\d+)[mM]#;
    $seconds += (3600 * $1)  if $runtime =~ m#(\+?\d+)[hH]#;
    $seconds += (86400 * $1) if $runtime =~ m#(\+?\d+)[dD]#;

# If we're only allowing so much CPU
#  Create a single pipe (from child to parent)
#  Perform the fork
#  Die now if the fork failed

    if ($cpu) {
        pipe my $child,my $parent;
        my $pid = fork();
        die "Could not fork: $!\n" unless defined $pid;

#  If we're in the child process
#   Close the reading part on this end
#   Make sure we can autoflush
#   Make sure the pipe to the parent flushes
        
        unless ($pid) {
            close $child;
            require IO::Handle;
            $parent->autoflush;

#   Install a signal handler which
#    Obtain the CPU time info
#    Calculate the total
#    Send that to the parent, rounded
#   Return now to let the child do its thing

            $SIG{INFO} = sub {
                my @time = times;
                my $time = $time[0] + $time[1] + $time[2] + $time[3];
                printf $parent "%.0f\n",$time;
            };
            return;
        }        

#  Install a signal handler that will exit parent process if child exits

        $SIG{CHLD} = sub { exit };

#  Close the writing part of the pipe on this end
#  Initialize CPU time burnt so far
#  While we have a child process and not all CPU time burnt
#   Sleep for the minimum time until CPU cycles burnt
#   Signal the child to tell its CPU usage
#   Until we received word from the child
#    Check if the child still runs, exit if child no longer there
#   Obtain time spent from child, exit if child no longer there

        close $parent;
        my $rbits; vec( $rbits,fileno( $child ),1 ) = 1;
        my $burnt = 0;
        while ($burnt < $seconds) {
            sleep $seconds - $burnt;
            kill 29,$pid;
            until (select $rbits,undef,undef,1) {
                exit unless kill 0,$pid;
            }
            exit unless defined( $burnt = <$child> );
        }

#  Kill the child process
#  And exit

        kill 15,$pid;
        exit;

# Else (only interested in wallclock)
#  Perform the fork
#  Die now if the fork failed
#  Return now if we're in the child process

    } else {
        my $pid = fork();
        die "Could not fork: $!\n" unless defined $pid;
        return unless $pid;  

#  Set the alarm handler which
#   Kills the child process
#   And does an exit, indicating a problem

        $SIG{ALRM} = sub {
            kill 15,$pid;
            exit 1;
        };

#  Set the alarm
#  Wait for the child process to return
#  Exit now, we're done okidoki

        alarm $seconds;
        wait;
        exit;
    }
} #import

#---------------------------------------------------------------------------

__END__

=head1 NAME

Sys::RunUntil - make sure script only runs for the given time

=head1 SYNOPSIS

 use Sys::RunUntil '30mW';
 # code which may only take 30 minutes to run

 use Sys::RunUntil '30sC';
 # code which may only take 30 seconds of CPU time

=head1 DESCRIPTION

Provide a simple way to make sure the script from which this module is
loaded, is running only for either the given wallclock time or a maximum
amount of CPU time.

=head1 METHODS

There are no methods.

=head2 RUNTIME SPECIFICATION

The maximum runtime of the script can be specified in seconds, or with any
combination of the following postfixes:

 - S seconds
 - M minutes
 - H hours
 - D days

The string "1H30M" would therefor indicate a runtime of 5400 seconds.

The letter B<C> indicates that the runtime is specified in CPU seconds used.
The (optional) letter B<W> indicates that the runtime is specified in wallclock
time.

=head1 THEORY OF OPERATION

The functionality of this module basically depends on C<alarm> and C<fork>,
with some pipes and selects mixed in when checking for CPU time.

=head2 Wallclock Time

When the "import" class method is called (which happens automatically with
C<use>), that method forks the process and sets an C<alarm> in the parent
process and waits for the child process to return.  If the process returns
before the C<alarm> is activated, that's ok.  If the C<alarm> is triggered,
it means that the child process is taking to long: the parent process will
then kill the child by sending it a TERM (15) signal and exit.

=head2 CPU time

When the "import" class method is called (which happens automatically with
C<use>), that method creates a pipe and forks the process.  In the child
process a signal handler is installed on the C<INFO> (29) signal which prints
the total CPU time used on the pipe to the parent.  The parent then waits
for the minimum amount of time that would need to expire before the CPU limit
in the child process is reached.  It then sends the INFO signal to the child
process to obtain the amount of CPU used by the child.  The parent then
decides to wait longer or to kill the child process by sending it a C<TERM>
(15) signal.

=head1 REQUIRED MODULES

 (none)

=head1 SEE ALSO

L<Sys::RunAlone>, L<Sys::RunAlways>.

=head1 AUTHOR

 Elizabeth Mattijsen

=head1 COPYRIGHT

Copyright (c) 2005 Elizabeth Mattijsen <liz@dijkmat.nl>. All rights
reserved.  This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
