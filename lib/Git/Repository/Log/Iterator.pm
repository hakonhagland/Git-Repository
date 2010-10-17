package Git::Repository::Log::Iterator;

use strict;
use warnings;
use Carp;

use Git::Repository;
use Git::Repository::Command;
use Git::Repository::Log;

our $VERSION = '1.00';

sub new {
    my ( $class, @cmd ) = @_;

    # pick up unsupported log options
    my @badopts = do {
        my $options = 1;
        grep {/^--(?:pretty=(?!raw)|graph)$/}
            grep { $options = 0 if $_ eq '--'; $options } @cmd;
    };
    carp "log() cannot parse @badopts. "
        . 'Use run( log => ... ) to parse the output yourself'
        if @badopts;

    # enforce the format
    @cmd = ( 'log', '--pretty=raw', @cmd );

    # run the command (@cmd may hold a Git::Repository instance)
    bless { cmd => Git::Repository::Command->new(@cmd) }, $class;
}

sub next {
    my ($self) = @_;
    my $fh = $self->{cmd}->stdout;

    # get records
    my @records = defined $self->{record} ? ( delete $self->{record} ) : ();
    {
        local $/ = "\n\n";
        while (<$fh>) {
            $self->{record} = $_, last if /\Acommit / && @records;
            push @records, $_;
        }
    }

    # EOF
    return if !@records;

    # the first two records are always the same, with --pretty=raw
    my ( $header, $message, $extra ) = ( @records, '' );
    my @headers = map { chomp; split / /, $_, 2 } split /^/m, $header;
    chomp( $message, $extra ) if exists $self->{record};

    # create the log object
    return Git::Repository::Log->new(
        @headers,
        message => $message,
        extra   => $extra,
    );
}

1;

__END__

=head1 NAME

Git::Repository::Log::Iterator - Split a git log stream into records

=head1 SYNOPSIS

    use Git::Repository::Log::Iterator;

    # use a default Git::Repository context
    my $iter = Git::Repository::Log::Iterator->new('HEAD~10..');

    # or provide an existing instance
    my $iter = Git::Repository::Log::Iterator->new( $r, 'HEAD~10..' );

    # get the next log record
    while ( my $log = $iter->next ) {
        ...;
    }

=head1 DESCRIPTION

C<Git::Repository::Log::Iterator> initiates a B<git log> command
from a list of paramaters and parses its output to produce
C<Git::Repository::Log> objects represening each log item.

=head1 METHODS

=head2 new( @args )

Create a new B<git log> stream from the parameter list in C<@args>
and return a iterator on it.

C<new()> will happily accept any parameters, but note that
C<Git::Repository::Log::Iterator> expects the output to look like that
of C<--pretty=raw>, and so will force the the C<--pretty> option
(in case C<format.pretty> is defined in the Git configuration).

Extra ouput (like patches) will be stored in the C<extra> parameter of
the C<Git::Repository::Log> object. Decorations will be lost.

When unsupported options are recognized in the parameter list, C<new()>
will C<carp()> with a message advising to use C<< run( 'log' => ... ) >>
to parse the output yourself.

=head2 next()

Return the next log item as a C<Git::Repository::Log> object,
or nothing if the stream has ended.

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book at cpan.org> >>

=head1 COPYRIGHT

Copyright 2010 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

