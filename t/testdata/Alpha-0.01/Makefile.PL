

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'Alpha',
    VERSION_FROM => 'lib/Alpha.pm', # finds \$VERSION
    AUTHOR       => 'James E Keenan (jkeen@verizon.net)',
    ABSTRACT     => 'Test module used to illustrate coverage analysis in Perl',
    PREREQ_PM    => {
                     'Test::Simple' => 0.44,
                    },
);
