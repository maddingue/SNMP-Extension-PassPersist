use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'SNMP::Extension::PassPersist',
    license             => 'perl',
    dist_author         => 'Sebastien Aperghis-Tramoni <sebastien@aperghis.net>',
    dist_version_from   => 'lib/SNMP/Extension/PassPersist.pm',
    requires => {
        'Class::Accessor'   => '0.30',
        'Getopt::Long'      => '2.04',
        'IO::Handle'        => '1.15',
        'IO::Select'        => '1.10',
        'List::MoreUtils'   => '0.21',
        'parent'            => '0.221',
    },
    build_requires => {
        'Test::More'        => '0.45',
    },
    add_to_cleanup      => [ 'SNMP-Extension-PassPersist-*' ],
);

$builder->create_build_script();
