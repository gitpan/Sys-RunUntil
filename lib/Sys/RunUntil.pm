package Sys::RunUntil;

# Set version
# Make sure we're strict

$VERSION = '0.01';
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
# Die now if invalid characters found

    my $runtime = $_[1];
    die "Must specify a time until which the script should run\n"
     unless defined $runtime;
    die "Unrecognizable runtime specified: $runtime\n"
     unless $runtime =~ m#^[sSmMhHdDwW\d]+$#;

# Convert seconds into seconds
# Convert minutes into seconds
# Convert hours into seconds
# Convert days into seconds
# Convert weeks into seconds

    my $seconds = 0;
    $seconds += $1            if $runtime =~ m#(\d+)[sS]#;
    $seconds += (60 * $1)     if $runtime =~ m#(\d+)[mM]#;
    $seconds += (3600 * $1)   if $runtime =~ m#(\+?\d+)[hH]#;
    $seconds += (86400 * $1)  if $runtime =~ m#(\+?\d+)[dD]#;
    $seconds += (604800 * $1) if $runtime =~ m#(\+?\d+)[wW]#;

# Perform the fork
# Die now if the fork failed
# Return now if we're in the child process

    my $pid = fork();
    die "Could not fork: $!\n" unless defined $pid;
    return unless $pid;  

# Set the alarm handler which
#  Kills the child process
#  And does an exit, indicating a problem

    $SIG{ALRM} = sub {
        kill 15,$pid;
        exit 1;
    };

# Set the alarm
# Wait for the child process to return
# Exit now, we're done okidoki

    alarm $seconds;
    wait;
    exit;
} #import

#---------------------------------------------------------------------------

__END__

=head1 NAME

Sys::RunUntil - make sure script only runs for the given time

=head1 SYNOPSIS

 use Sys::RunUntil '30m';
 # code which may only take 30 minutes to run

=head1 DESCRIPTION

Provide a simple way to make sure the script from which this module is
loaded, is running only for the given (wallclock) time.

=head1 METHODS

There are no methods.

=head2 RUNTIME SPECIFICATION

The maximum runtime of the script can be specified in seconds, or with any
combination of the following postfixes:

 - S seconds
 - M minutes
 - H hours
 - D days
 - W weeks

A runtime of "1H30M" would therefor indicate a runtime of 5400 seconds.

=head1 THEORY OF OPERATION

The functionality of this module basically depends on C<alarm> and C<fork>.
When the "import" class method is called (which happens automatically with
C<use>), that method sets an C<alarm> and then forks the process and waits
for the process to return.  If the process returns before the C<alarm> is
activated, that's ok.  If the C<alarm> is triggered, it means that the child
process is taking to long: the parent process will then kill the child by
sending it a TERM (15) signal.

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
