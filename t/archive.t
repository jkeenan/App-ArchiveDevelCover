use 5.010;
use strict;
use warnings;
use lib qw(t);

use Test::Most;
use Test::Trap;
use Test::File;
use testdata::setup;
use App::ArchiveDevelCover;
use Data::Dumper;$Data::Dumper::Indent=1;

my $temp = testdata::setup::tmpdir();
my $dt_str = '2012-02-20T18:20:00';

{ # first archive
    my $run = testdata::setup::run($temp,'run_1');

    my $a = App::ArchiveDevelCover->new(
        from    =>  $run,
        to      =>  $temp->subdir('archive'),
    );
    isa_ok($a, 'App::ArchiveDevelCover');
#    trap { $a->run; };
say STDERR "from: ", $a->from;
say STDERR "to: ", $a->to;
say STDERR "archive_db: ", $a->archive_db;
say STDERR "project: ", $a->project;
    my ($target_path) = trap { $a->archive; };
    ok($target_path, "archive() returned true value: target_string $target_path");
    like(
        $trap->stdout,
        qr/archived coverage reports at \Q$temp\E/,
        "command output location: $temp",
    );
    my @files_created = glob("$target_path/*");
    is(@files_created, 6, "Got 6 expected files in temporary archive directory");
    ok(! (-e $a->archive_db), "archive_db file does not yet exist");

    my ($rv) = trap { $a->generate_diff };
    ok(! defined $rv, "first run, hence no previous statistics");

#say STDERR Dumper \@files_created;
#    0trap->exit, undef, 'exit() == undef' );
#
#    foreach my $file (qw(index.html cover.css archive_db $dt_str/coverage.html)) {
#        file_exists_ok($temp->file('archive',$file));
#    }
#
#    my $index = $temp->file('archive','index.html')->slurp;
#    my @temp = $temp->dir_list;
#    my $title = 'Test Coverage Archive for '.$temp[-1];
#    like($index,qr/$title/,'project title');
#    like($index,qr#href="\./$dt_str/coverage\.html#,'link to coverage');
#    like($index,qr#href="\./$dt_str/diff\.html#,'link to diff');
}

{ # archive the same run again
    my $a = App::ArchiveDevelCover->new(
        from=>$temp->subdir('run_1'),
        to=>$temp->subdir('archive'),
    );
    isa_ok($a, 'App::ArchiveDevelCover');
    trap { $a->archive; };
#    is ( $trap->exit, 0, 'exit() == 0' );
    like($trap->stdout,qr/This coverage report has already been archived/i,'command output again');
}

#{ # archive second run
#    my $run = testdata::setup::run($temp,'run_2');
#
#    my $a = App::ArchiveDevelCover->new(
#        from=>$run,
#        to=>$temp->subdir('archive'),
#    );
#    trap { $a->run; };
#    is ( $trap->exit, undef, 'exit() == undef' );
#    like($trap->stdout,qr/archived coverage reports at \Q$temp\E/,'command output location');
#
#    foreach my $file (qw(index.html cover.css archive_db 2012-02-20T19:40:00/coverage.html)) {
#        file_exists_ok($temp->file('archive',$file));
#    }
#    my @archive = $temp->file('archive','archive_db')->slurp;
#    is(@archive,2,'2 lines in archive_db');
#
#    my $l1 = shift(@archive);
#    chomp($l1);
#    my @d1 = split(/;/,$l1);
#    is($d1[3],'18.5','first line total coverage');
#
#    my $l2 = shift(@archive);
#    chomp($l2);
#    my @d2 = split(/;/,$l2);
#    is($d2[3],'76.2','second line total coverage');
#}

done_testing();
