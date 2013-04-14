use 5.010;
use strict;
use warnings;

use Data::Dumper;$Data::Dumper::Indent=1;

use Test::More qw(no_plan);
use Test::Trap;
use App::ArchiveDevelCover;
use File::Temp qw(tempdir);
use Path::Class;
use File::Copy::Recursive qw(dircopy);
require Devel::Cover;
use Carp;
use Cwd;
use File::Path qw(make_path);
use IO::CaptureOutput qw(capture);

sub test_cover_sample_files {
    my $tdir = shift;
    my $cwd = cwd();
    chdir $tdir or croak "Unable to change to tempdir";
    local $ENV{HARNESS_PERL_SWITCHES} = '-MDevel::Cover';
    system(qq{$^X Makefile.PL && make && make test})
        and croak "Unable to run make and make test";
    system(qq{cover -report text > /dev/null})
        and croak "Unable to run cover";
    chdir $cwd;
}

my $samplepkg = 'Alpha-0.01';
my $sampledir = "./t/testdata/$samplepkg";
ok(-d $sampledir, "Found sample code for testing");
my $top_tdir =
    Path::Class::Dir->new(tempdir(CLEANUP=>$ENV{NO_CLEANUP} ? 0 : 1));
ok(-d $top_tdir, "Created top tempdir $top_tdir for testing");
my $tdir = Path::Class::Dir->new($top_tdir, $samplepkg);
make_path($tdir, { mode => 0777 });
ok(-d $tdir, "Created tempdir $tdir for testing");
my $dt_str = '2012-02-20T18:20:00';

dircopy($sampledir, $tdir) or die $!;

{
    {
        my ($stdout, $stderr);
        capture(
            sub { test_cover_sample_files($tdir); },
            \$stdout,
            \$stderr,
        );
        ok(! $stderr, "No errors in testing/covering sample files");
    }
    my $a = App::ArchiveDevelCover->new(
        from    =>  $tdir,
        to      =>  $tdir->subdir('archive'),
    );
    isa_ok($a, 'App::ArchiveDevelCover');
    isa_ok($a->devel_cover_db, 'Devel::Cover::DB');

    my $target_path;
    ($target_path) = trap { $a->archive; };
    ok($target_path,
        "archive() returned true value: target_string $target_path");

    # second run: should say archive already done
    ($target_path) = trap { $a->archive; };
    like(
        $trap->stderr,
        qr/This coverage report has already been archived/i,
        "Got expected error when report was already archived",
    );
}

