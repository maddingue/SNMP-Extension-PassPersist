use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'SNMP::Extension::PassPersist',
    license             => 'perl',
    dist_author         => 'Sebastien Aperghis-Tramoni <sebastien@aperghis.net>',
    dist_version_from   => 'lib/SNMP/Extension/PassPersist.pm',
    build_requires => {
        'Test::More'    => 0,
    },
    add_to_cleanup      => [ 'SNMP-Extension-PassPersist-*' ],
);

$builder->create_build_script();
