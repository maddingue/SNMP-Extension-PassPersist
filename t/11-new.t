#!perl
use strict;
use warnings;
use Test::More;
use SNMP::Extension::PassPersist;


my $module = "SNMP::Extension::PassPersist";
my @cases  = (
    {
        args => [],
        diag => qr/^$/,
    },
    {
        args => [ {} ],
        diag => qr/^$/,
    },
    {
        args => [ 42 ],
        diag => qr/^error: Odd number of arguments/,
    },
    {
        args => [ 1, 2, 3 ],
        diag => qr/^error: Odd number of arguments/,
    },
    {   # unknown attributes are ignored
        args => [ foo => "bar" ],
        diag => qr/^$/,
    },
    {
        args => [ { foo => "bar" } ],
        diag => qr/^$/,
    },
    {
        args => [ \my $var ],
        diag => qr/^error: Don't know how to handle scalar reference/,
    },
    {
        args => [ [] ],
        diag => qr/^error: Don't know how to handle array reference/,
    },
    {
        args => [ sub {} ],
        diag => qr/^error: Don't know how to handle code reference/,
    },
    {   # checking that code attributes are correctly checked
        args => [ backend_init => sub {} ],
        diag => qr/^$/,
    },
    {
        args => [ backend_init => [] ],
        diag => qr/^error: Attribute backend_init must be a code reference/,
    },
    {
        args => [ backend_init => {} ],
        diag => qr/^error: Attribute backend_init must be a code reference/,
    },
);

plan tests => ~~@cases;

for my $case (@cases) {
    my $args = $case->{args};
    my $diag = $case->{diag};
    my $object = eval { $module->new(@$args) };
    like( $@, $diag, "$module->new(".join(", ", @$args).")" );
}
