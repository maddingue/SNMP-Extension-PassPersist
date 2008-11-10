#!perl
use strict;
use warnings;
use Test::More;
use File::Temp ();
use IO::File;
use lib "t";
use Utils;


plan tests => 7;

my $module = "SNMP::Extension::PassPersist";

# input data
my ($oid, $type, $value) = qw<.1.2.3 integer 42>;
my $input  = "get\n$oid\n";

# expected data
my %expected_tree = (
    $oid => [ $type => $value ],
);
my $expected_output = join $/, $oid, $type, $value, "";

# load the module
use_ok($module);

# create the object
my $extsnmp = eval { $module->new(backend_collect => \&update_tree) };
is( $@, "", "$module->new" );
isa_ok( $extsnmp, $module, "chek that \$extsnmp" );
my $i = 1;

sub update_tree {
    my ($self) = @_;
    eval { $extsnmp->add_oid_entry($oid, $type, $value) };
    is( $@, "", "[$i] update_tree(): add_oid_entry('$oid', '$type', '$value')" );
    is_deeply( $extsnmp->oid_tree, \%expected_tree,
        "[$i] update_tree(): check internal OID tree consistency" );
    $i++;
}

# execute the main loop
my $fh = File::Temp->new;
$fh->print($input);
$fh->close;
my ($stdin, $stdout) = ( IO::File->new($fh->filename), wo_fh(\my $output) );
$extsnmp->input($stdin);
$extsnmp->output($stdout);
$extsnmp->idle_count(1);
$extsnmp->refresh(1);
eval { $extsnmp->run };
is( $@, "", "\$extsnmp->run" );
is( $output, $expected_output, "check the output" );
