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

use constant HAVE_SORT_KEY_OID => eval "use Sort::Key::OID qw<oidsort>; 1"?1:0;


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
    ipaddr      => "ipaddress",
    ipaddress   => "ipaddress",
    netaddr     => "ipaddress",
    objectid    => "objectid",
    octetstr    => "string",
#   opaque      => "opaque",
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
                $self->output->print(join $/, @result, "");
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
    $self->oid_tree->{$oid} = [$type => $value];
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

    my @entries = HAVE_SORT_KEY_OID
                ? oidsort(keys %{ $self->oid_tree })
                : sort by_oid keys %{ $self->oid_tree };

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

    my @entries = HAVE_SORT_KEY_OID
                ? oidsort(keys %{ $self->oid_tree })
                : sort by_oid keys %{ $self->oid_tree };
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

This module is a framework for writing Net-SNMP extensions using the
C<pass> or C<pass_persist> mechanisms.

When in C<pass_persist> mode, it provides a mechanism to spare
ressources by quitting from the main loop after a given number of
idle cycles.

This module can use C<Sort::Key::OID> when it is available, for sorting
OIDs faster than with the internal pure Perl function.


=head1 METHODS

=head2 new()

Creates a new object. Can be given any attributes as a hash or hashref.
See L<"ATTRIBUTES"> for the list of available attributes.

B<Examples:>

    # for a "pass" command, most attributes are useless
    my $extsnmp = SNMP::Extension::PassPersist->new;

    # for a "pass_persist" command, you'll usually want to
    # at least set the backend_collect callback
    my $extsnmp = SNMP::Extension::PassPersist->new(
        backend_collect => \&update_tree,
        idle_count      => 10,      # no more than 10 idle cycles
        refresh         => 10,      # refresh every 10 sec
    );

=head2 run()

This method does the following things:

=over

=item *

process the command line arguments in order to decide in which mode
the program has to be executed

=item *

call the backend init callback

=item *

call the backend collect callback a first time

=back

Then, when in "pass" mode, the corresponding SNMP command is executed,
its result is printed on the output filehandle, and C<run()> returns.

When in "pass_persist" mode, C<run()> enters a loop, reading Net-SNMP
queries on its input filehandle, processing them, and printing result
on its output filehandle. The backend collect callback is called every
C<refresh> seconds. If no query is read from the input after C<idle_count>
cycles, C<run()> returns.

=head2 add_oid_entry(FUNC_OID, FUNC_TYPE, FUNC_VALUE)

Add an entry to the OID tree.

=head2 add_oid_tree(HASH)

Merge an OID tree to the main OID tree, using the same structure as
the one of the OID tree itself.


=head1 ATTRIBUTES

This module's attributes are generated by C<Class::Accessor>, and can
therefore be passed as arguments to C<new()> or called as object methods.

=head2 backend_init

Set the code reference for a backend callback that will be called only
once, at the beginning of C<run()>, just after parsing the command-line
arguments. See also L<"CALLBACKS">.

=head2 backend_collect

Set the code reference for a backend callback that will be called every
C<refresh> seconds to update the OID tree. See also L<"CALLBACKS">.

=head2 dispatch

Gives access to the internal dispatch table, stored as a hash with the
following structure:

    dispatch => {
        SNMP_CMD  =>  { nargs => NUMBER_ARGS,  code => CODEREF },
        ...
    }

where the SNMP command is always in lowercase, C<nargs> gives the number
of arguments expected by the command and C<code> the callback reference.

You should not modify this table unless you really know what you're doing.

=head2 idle_count

Get/set the number of idle cycles before ending the run loop.

=head2 input

Get/set the input filehandle.

=head2 oid_tree

Gives access to the internal OID tree, stored as a hash with the
following structure:

    oid_tree => {
        FUNC_OID  =>  [ FUNC_TYPE, FUNC_VALUE ],
        ...
    }

where C<FUNC_OID> is the absolute OID of the SNMP function, C<FUNC_TYPE>
the function type (C<"integer">, C<"counter">, C<"gauge">, etc), and
C<FUNC_VALUE> the function value.

You should not directly modify this hash but instead use the appropriate
methods for adding OID entries.

=head2 output

Get/set the output filehandle.

=head2 refresh

Get/set the refresh delay before calling the backend collect callback
to update the OID tree.


=head1 CALLBACKS

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
L<http://rt.cpan.org/Public/Dist/Display.html?Name=SNMP-Extension-PassPersist>.
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

32272
