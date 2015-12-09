package Text::Plagiarism;
use common::sense;
# TODO think of interface!
use Exporter::Easy (
    EXPORT  => [qw(
        plagiarizm_prepare
        how_much_plagiarized
    )],
);

=head1 NAME

Text::Plagiarism - modules checks plagirism in texts

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

TODO
Quick summary of what the module does.

Perhaps a little code snippet.

    use Text::Plagiarism;

    my $tp = Text::Plagiarism->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 plagiarizm_prepare

it prepares help data for plagiarizm search (shingles, hashes)

=cut

sub plagiarizm_prepare {
    my %a   = (
        text    => undef,
        @_
    );

    my %d;
    \%d;
}

=head2 how_much_plagiarized

measures how much 1st text is a plagiarization of 2nd one

=cut

sub how_much_plagiarized {
    my %a   = (
        text0   => undef,
        data0   => {},
        text1   => undef,
        data1   => {},
        @_
    );

    undef;
}

=head1 AUTHOR

Alex Sudakov, C<< <cygakoB at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-text-plagiarism at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Text-Plagiarism>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Text::Plagiarism

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Text-Plagiarism>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Text-Plagiarism>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Text-Plagiarism>

=item * Search CPAN

L<http://search.cpan.org/dist/Text-Plagiarism/>

=back


=head1 ACKNOWLEDGEMENTS

Thanks for METER corpus and advices to Paul D Clough.

Daniel Bär, Torsten Zesch, and Iryna Gurevych.
Text Reuse Detection Using a Composition of Text Similarity Measures.
In Proceedings of the 24th International Conference on Computational Linguistics, December 2012, Mumbai, India.

Clough, P., Gaizauskas, R. and Piao, S. L. (2002),
Building and annotating a corpus for the study of journalistic text reuse.
In Proceedings of the 3rd International Conference on Language Resources and Evaluation (LREC-02),
pp.1678-1691 (Vol V), 29-31st May 2002, Los Palmas de Gran Canaria, Spain.

=head1 LICENSE AND COPYRIGHT

Copyright 2015 Alex Sudakov.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

8;
