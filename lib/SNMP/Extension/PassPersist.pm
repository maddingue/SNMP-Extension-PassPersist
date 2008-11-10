package SNMP::Extension::PassPersist;
use strict;
use warnings;

use parent qw(Class::Accessor);

use Carp;
use Getopt::Long    qw(:config no_auto_abbrev no_ignore_case);
use IO::Handle;
use IO::Select;
use List::MoreUtils qw(any);


{
    no strict "vars";
    $VERSION = '0.01';
}


=head1 NAME

SNMP::Extension::PassPersist - Generic pass/pass_persist extension framework
for Net-SNMP

=head1 VERSION

This is the documentation of C<SNMP::Extension::PassPersist> version 0.01

=cut


# early initialisations --------------------------------------------------------
my @attributes = qw<
    backend_init
    backend_collect
    idle_count
    input
    oid_tree
    output
    refresh
    dispatch
>;

__PACKAGE__->mk_accessors(@attributes);


# constants --------------------------------------------------------------------
use constant {
    SNMP_NONE               => "NONE",
    SNMP_PING               => "PING",
    SNMP_PONG               => "PONG",
    SNMP_GET                => "get",
    SNMP_GETNEXT            => "getnext",
    SNMP_SET                => "set",
    SNMP_NOT_WRITABLE       => "not-writable",
    SNMP_WRONG_TYPE         => "wrong-type",
    SNMP_WRONG_LENGTH       => "wrong-length",
    SNMP_WRONG_VALUE        => "wrong-value",
    SNMP_INCONSISTENT_VALUE => "inconsistent-value",
};


# global variables -------------------------------------------------------------
my %snmp_ext_type = (
    counter     => "counter",
    gauge       => "gauge",
    integer     => "integer",
    ipaddress   => "ipaddress",
    objectid    => "objectid",
    octetstr    => "string",
    timeticks   => "timeticks",
);



#
# new()
# ---
sub new {
    my ($class, @args) = @_;
    my %attrs;

    # see how arguments were passed
    if (ref $args[0] and ref $args[0] eq "HASH") {
        %attrs = %{$args[0]};
    }
    else {
        croak "error: Odd number of arguments"  if @args % 2 == 1;
        %attrs = @args;
    }

    # filter out unknown attributes
    my %known_attr;
    @known_attr{@attributes} = (1) x @attributes;
    !$known_attr{$_} && delete $attrs{$_} for keys %attrs;

    # check that code attributes are coderefs
    for my $code_attr (qw<backend_init backend_collect>) {
        croak "error: Attribute $code_attr must be a code reference"
            if defined $attrs{$code_attr} and ref $attrs{$code_attr} ne "CODE";
    }

    # default values
    %attrs = (
        backend_init    => sub {},
        backend_collect => sub {},
        input       => \*STDIN,
        output      => \*STDOUT,
        oid_tree    => {},
        idle_count  => 5,
        refresh     => 10,
        dispatch    => {
            lc(SNMP_PING)    => { nargs => 0,  code => \&ping        },
            lc(SNMP_GET)     => { nargs => 1,  code => \&get_oid     },
            lc(SNMP_GETNEXT) => { nargs => 1,  code => \&getnext_oid },
            lc(SNMP_SET)     => { nargs => 2,  code => \&set_oid     },
        },
        %attrs,
    );

    # create the object with Class::Accessor
    my $self = $class->SUPER::new(\%attrs);

    return $self
}


#
# run()
# ---
sub run {
    my ($self) = @_;

    # process command-line arguments
    Getopt::Long::Configure(qw<no_auto_abbrev no_ignore_case>);
    GetOptions(\my %options, qw<get|g=s  getnext|n=s  set|s=s>)
        or croak "fatal: An error occured while processing runtime arguments";

    # collect the information
    $self->backend_init->();
    $self->backend_collect->();

    # Net-SNMP "pass" mode
    if (any {defined $options{$_}} qw<get getnext set>) {
        for my $op (qw<get getnext set>) {
            if ($options{$op}) {
                my @args = split /,/, $options{$op};
                my $coderef = $self->dispatch->{$op}{code};
                my @result = $self->$coderef(@args);
                print join $/, @result, "";
            }
        }
    }
    # Net-SNMP "pass_persist" mode
    else {
        my $needed  = 1;
        my $delay   = $self->refresh;
        my $counter = $self->idle_count;

        my $io = IO::Select->new;
        $io->add($self->input);
        $self->output->autoflush(1);

        while ($needed and $counter > 0) {
            my $start_time = time;

            if (my($input) = $io->can_read($delay)) {
                if (my $cmd = <$input>) {
                    $self->process_cmd(lc($cmd), $input)
                }
                else {
                    $needed = 0
                }
            }

            $delay = $delay - (time() - $start_time);

            if ($delay <= 0) {
                # collect information when the timeout has expired
                $self->backend_collect->();

                # reset delay
                $delay = $self->refresh;
                $counter--;
            }
        }
    }
}


#
# add_oid_entry()
# -------------
sub add_oid_entry {
    my ($self, $oid, $type, $value) = @_;
    croak "*** not implemented ***"
}


#
# add_oid_tree()
# ------------
sub add_oid_tree {
    my ($self, $oid_tree) = @_;
    croak "*** not implemented ***"
}


#
# ping()
# ----
sub ping {
    return SNMP_PONG
}


#
# get_oid()
# -------
sub get_oid {
    my ($self, $req_oid) = @_;

    my $oid_tree = $self->oid_tree;
    my @result = ();

    if ($oid_tree->{$req_oid}) {
        my ($type, $value) = @{ $oid_tree->{$req_oid} };
        @result = ($req_oid, $type, $value);
    }
    else {
        @result = (SNMP_NONE)
    }

    return @result
}


#
# getnext_oid()
# -----------
sub getnext_oid {
    my ($self, $req_oid) = @_;

    my $next_oid = $self->fetch_next_entry($req_oid)
                || $self->fetch_first_entry();

    return $self->get_oid($next_oid)
}


#
# set_oid()
# -------
sub set_oid {
    my ($self, $req_oid, $value) = @_;
    return SNMP_NOT_WRITABLE
}


# 
# process_cmd()
# -----------
# Process and dispatch Net-SNMP commands when in pass_persist mode.
# 
sub process_cmd {
    my ($self, $cmd, $fh) = @_;
    my @result = ();

    chomp $cmd;
    my $dispatch = $self->dispatch;

    if (exists $dispatch->{$cmd}) {

        # read the command arguments
        my @args = ();
        my $n    = $dispatch->{$cmd}{nargs};

        while ($n-- > 0) {
            chomp(my $arg = <$fh>);
            push @args, $arg;
        }

        # call the command handler
        my $coderef = $dispatch->{$cmd}{code};
        @result = $self->$coderef(@args);
    }
    else {
        @result = SNMP_NONE;
    }

    # output the result
    $self->output->print(join $/, @result, "");
}


#
# fetch_next_entry()
# ----------------
sub fetch_next_entry {
    my ($self, $req_oid) = @_;

    my @entries = sort by_oid keys %{ $self->oid_tree };

    # find the index of the current entry
    my $curr_entry_idx = -1;

    for my $i (0..$#entries) {
        # exact match of the requested entry
        $curr_entry_idx = $i and last if $entries[$i] eq $req_oid;

        # prefix match of the requested entry
        $curr_entry_idx = $i - 1
            if index($entries[$i], $req_oid) >= 0 and $curr_entry_idx == -1;
    }

    # get the next entry if it exists, otherwise none
    my $next_entry_oid = $entries[$curr_entry_idx + 1] || SNMP_NONE;

    return $next_entry_oid
}


#
# fetch_first_entry()
# -----------------
sub fetch_first_entry {
    my ($self) = @_;

    my @entries = sort by_oid keys %{ $self->oid_tree };
    my $first_entry_oid = $entries[0];

    return $first_entry_oid
}


# 
# by_oid()
# ------
# sort() sub-function, for sorting by OID
#
sub by_oid ($$) {
    my @a = split /\./, $_[0];
    my @b = split /\./, $_[1];
    my $v = 0;
    $v ||= $a[$_] <=> $b[$_] for 0 .. $#a;
    return $v
}



=head1 SYNOPSIS

    # typical setup for a pass programm
    use SNMP::Extension::PassPersist;

    # create the object
    my $extsnmp = SNMP::Extension::PassPersist->new;

    # add a few OID entries
    $extsnmp->add_oid_entry($oid, $type, $value);
    $extsnmp->add_oid_entry($oid, $type, $value);

    # run the program
    $extsnmp->run;


    # typical setup for a pass_persist program
    use SNMP::Extension::PassPersist;

    my $extsnmp = SNMP::Extension::PassPersist->new(
        backend_collect => \&update_tree
    );
    $extsnmp->run;


    sub update_tree {
        my ($self) = @_;

        # add a serie of OID entries
        $self->add_oid_entry($oid, $type, $value);
        ...
    
        # or directly add a whole OID tree
        $self->add_oid_tree(\%oid_tree);
    }


=head1 DESCRIPTION

....

=head1 METHODS

...


=head1 SEE ALSO

L<SNMP::Persist> is another pass_persist backend for writing Net-SNMP 
extensions, but relies on threads.

The documentation of Net-SNMP, especially the part on how to configure
a pass or pass_persist extension:

=over

=item *

main site: L<http://www.net-snmp.org/>

=item *

configuring a pass or pass_persist extension:
L<http://www.net-snmp.org/docs/man/snmpd.conf.html#lbAY>

=back


=head1 AUTHOR

SE<eacute>bastien Aperghis-Tramoni, C<< <sebastien at aperghis.net> >>


=head1 BUGS

Please report any bugs or feature requests to 
C<bug-snmp-extension-passpersist at rt.cpan.org>, 
or through the web interface at 
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=SNMP-Extension-PassPersist>. 
I will be notified, and then you'll automatically be notified of 
progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SNMP::Extension::PassPersist


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/Dist/Display.html?Queue=SNMP-Extension-PassPersist>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/SNMP-Extension-PassPersist>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/SNMP-Extension-PassPersist>

=item * Search CPAN

L<http://search.cpan.org/dist/SNMP-Extension-PassPersist>

=back


=head1 COPYRIGHT & LICENSE

Copyright 2008 SE<eacute>bastien Aperghis-Tramoni, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1
