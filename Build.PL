use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'SNMP::Extension::PassPersist',
    license             => 'perl',
    dist_author         => 'Sebastien Aperghis-Tramoni <sebastien@aperghis.net>',
    dist_version_from   => 'lib/SNMP/Extension/PassPersist.pm',
    requires => {
        'perl'              => '5.006',
        'Class::Accessor'   => '0.30',
        'Getopt::Long'      => '2.04',
        'IO::Handle'        => '1.15',
        'IO::Select'        => '1.10',
        'List::MoreUtils'   => '0.21',
        'parent'            => '0.221',
    },
    recommends => {
        'Sort::Key::OID'    => '0.04',
    },
    build_requires => {
        'File::Temp'        => '0.14',
        'IO::File'          => '1.05',
        'IO::String'        => '1.00',
        'Test::More'        => '0.45',
    },
    add_to_cleanup      => [ 'SNMP-Extension-PassPersist-*' ],
);

$builder->create_build_script();
