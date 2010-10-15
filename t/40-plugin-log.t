use strict;
use warnings;
use lib 't';
use Test::More;
use File::Temp qw( tempdir );
use File::Spec;
use Cwd qw( cwd abs_path );
use Git::Repository;

plan skip_all => 'Default git binary not found in PATH'
    if !Git::Repository::Command::_has_git('git');

my $version = Git::Repository->version;
plan skip_all => "these tests require git >= 1.5.0, but we only have $version"
    if Git::Repository->version_lt('1.5.0');

# clean up the environment
delete @ENV{qw( GIT_DIR GIT_WORK_TREE )};
my $home = cwd();

# a place to put a git repository
my $dir = abs_path( tempdir( CLEANUP => 1 ) );

plan tests => my $tests;

# first create a new empty repository
chdir $dir;
BEGIN { $tests += 1 }
ok( my $r = eval { Git::Repository->create('init') },
    q{Git::Repository->create( 'init' ) => dir }
);
diag $@ if !$r;
my $gitdir = $r->git_dir;

# make sure 't' is still where it should be
chdir $home;

# some test data
my %commit = (
    1 => {
        tree    => 'df2b8fc99e1c1d4dbc0a854d9f72157f1d6ea078',
        parent  => [],
        subject => 'empty file',
        body    => '',
        extra   => '',
    },
    2 => {
        tree    => '6820ead72140bd33a7a821965a05f9a1e89bf3c8',
        parent  => [],
        subject => 'one line',
        body    => 'of data',
        extra   => '',
    },
);

sub check_commit {
    my ( $id, $log ) = @_;
    my $commit = $commit{$id};
    is( $log->tree, $commit->{tree}, "commit $id tree" );
    is_deeply( [ $log->parent ], $commit->{parent}, "commit $id parent" );
    is( $log->subject, $commit->{subject}, "commit $id subject" );
    is( $log->body,    $commit->{body},    "commit $id body" );
    is( $log->extra,   $commit->{extra},   "commit $id extra" );
}

# no log method yet
BEGIN { $tests += 3 }
ok( !eval { $r->log('-1') }, 'no log() method' );

# load the log method
use_ok( 'Git::Repository', 'Log' );
ok( eval { $r->log('-1') }, 'log() method exists now' );

# create an empty file and commit it
BEGIN { $tests += 2 }
my $file = File::Spec->catfile( $dir, 'file' );
do { open my $fh, '>', $file; };
$r->run( add => 'file' );
$r->run( commit => '-m', $commit{1}{subject} );
my @log = $r->log();
is( scalar @log, 1, '1 commit' );
isa_ok( $_, 'Git::Repository::Log' ) for @log;

# check some log details
BEGIN { $tests += 5 }
check_commit( 1 => $log[0] );
push @{ $commit{2}{parent} }, $log[0]->commit;

# create another commit
BEGIN { $tests += 3 }
do { open my $fh, '>', $file; print $fh 'line 1'; };
$r->run( add => 'file' );
$r->run( commit => '-m', "$commit{2}{subject}\n\n$commit{2}{body}" );
@log = $r->log();
is( scalar @log, 2, '2 commits' );
isa_ok( $_, 'Git::Repository::Log' ) for @log;

# check some log details
BEGIN { $tests += 5 }
check_commit( 2 => $log[0] );

# try as a class method
BEGIN { $tests += 8 }
chdir $dir;
@log = Git::Repository->log();
is( scalar @log, 2, '2 commits' );
isa_ok( $_, 'Git::Repository::Log' ) for @log;

check_commit( 2 => $log[0] );

chdir $home;

