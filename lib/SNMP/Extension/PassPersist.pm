package SNMP::Extension::PassPersist;

use strict;
use warnings;


{
    no strict "vars";
    $VERSION = '0.01';
}

=head1 NAME

SNMP::Extension::PassPersist - Generic pass/pass_persist extension framework
for Net-SNMP

=head1 VERSION

This is the documentation of C<SNMP::Extension::PassPersist> version 0.01


=head1 SYNOPSIS

    use SNMP::Extension::PassPersist;

    my $foo = SNMP::Extension::PassPersist->new();
    ...

=head1 DESCRIPTION

....

=head1 METHODS

...


=head1 SEE ALSO

L<SNMP::Persist> is another pass_persist backend for writing Net-SNMP 
extensions, but relies on threads.


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
