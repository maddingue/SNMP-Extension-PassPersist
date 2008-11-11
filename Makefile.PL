use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'SNMP::Extension::PassPersist',
    AUTHOR              => 'Sebastien Aperghis-Tramoni <sebastien@aperghis.net>',
    VERSION_FROM        => 'lib/SNMP/Extension/PassPersist.pm',
    ABSTRACT_FROM       => 'lib/SNMP/Extension/PassPersist.pm',
    PREREQ_PM => {
        # prereqs
        'Class::Accessor'   => '0.30',
        'Getopt::Long'      => '2.04',
        'File::Temp'        => '0.12',
        'IO::File'          => '1.05',
        'IO::Handle'        => '1.15',
        'IO::Select'        => '1.10',
        'IO::String'        => '1.00',
        'List::MoreUtils'   => '0.21',
        'parent'            => '0.221',

        # build/test prereqs
        'Test::More'        => '0.45',
    },
    PL_FILES            => {},
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'SNMP-Extension-PassPersist-*' },
);
