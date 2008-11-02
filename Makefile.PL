use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'SNMP::Extension::PassPersist',
    AUTHOR              => 'Sebastien Aperghis-Tramoni <sebastien@aperghis.net>',
    VERSION_FROM        => 'lib/SNMP/Extension/PassPersist.pm',
    ABSTRACT_FROM       => 'lib/SNMP/Extension/PassPersist.pm',
    PREREQ_PM => {
        # build/test prereqs
        'Test::More'    => 0,
    },
    PL_FILES            => {},
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'SNMP-Extension-PassPersist-*' },
);
