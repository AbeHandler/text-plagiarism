package Text::Plagiarism;
use common::sense;
use Exporter::Easy (
    EXPORT  => [qw(
        plagiarism_prepare
        plagiarism_prepare_text
        plagiarism_measure
        plagiarism_measure_sentence

        $SENTENCE_EXACT_MATCH
        $SENTENCE_MINOR_REVISION
        $SENTENCE_MAJOR_REVISION
        $SENTENCE_SPECIFIC_TOPIC
        $SENTENCE_GENERAL_TOPIC
        $SENTENCE_UNRELATED

        $SENTENCE_IDENTICAL    
        $SENTENCE_MAJOR_OVERLAP
        $SENTENCE_MINOR_OVERLAP
        $SENTENCE_UNRELATED    

        measure2number
        measure2string
    )],
);
use Readonly;
use Lingua::Stem;
use Data::Dumper;

=encoding utf8

=cut

Readonly our $DEFAULT_NGRAM                             => 2;
Readonly our $DEFAULT_MIN_SENTENCE_LENGTH               => 4;

# sentence level matching results
Readonly our $SENTENCE_EXACT_MATCH       => '1 exact match';
Readonly our $SENTENCE_MINOR_REVISION    => '0.8 minor revision';
Readonly our $SENTENCE_MAJOR_REVISION    => '0.6 major revision';
Readonly our $SENTENCE_SPECIFIC_TOPIC    => '0.4 specific topic';
Readonly our $SENTENCE_GENERAL_TOPIC     => '0.2 general topic';
Readonly our $SENTENCE_UNRELATED         => '0 unrelated';
# document level matching results
Readonly our $DOCUMENT_IDENTICAL         => '1 identical';
Readonly our $DOCUMENT_MAJOR_OVERLAP     => '0.66 major overlap';
Readonly our $DOCUMENT_MINOR_OVERLAP     => '0.33 minor overlap';
Readonly our $DOCUMENT_UNRELATED         => '0 unrelated';

=head1 NAME

Text::Plagiarism - modules checks plagirism in texts

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Allow you to measure how much are 2 sentences/documents are identical.

TODO code snippet.

    use Text::Plagiarism qw(function and readonly vars list);

    my $m   = plagiarise_measure(
        query_text      => 'TEXT',
        document_text   => 'TEXT',
    );
    given($m) {
        when($Text::Plagiarism::DOCUMENT_IDENTICAL) {
            # actions for identical docs
        }
        when([
            $Text::Plagiarism::DOCUMENT_MAJOR_OVERLAP,
            $Text::Plagiarism::DOCUMENT_MINOR_OVERLAP,
        ]) {
            # actions for overlap docs
        }
        when($Text::Plagiarism::DOCUMENT_UNRELATED) {
            # actions for identical docs
        }
        default {
            die "unexpected result: '$_'";
        }
    }

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 plagiarism_prepare

It prepares help data for plagiarism search (shingles, hashes).

=cut

sub plagiarism_prepare {
    my %a   = (
        text                => undef,
        sentences           => undef,
        shingles_prepare    => undef,
        ngram               => $DEFAULT_NGRAM,
        @_
    );

    my %d   = %{ plagiarism_prepare_text(%a) // {} };

    if(defined $a{sentences}) {
        if($a{sentences}) {
            $d{sentences}   = [
                map { {
                    string      => $_,
                    shingles    => string2shingles(
                        string  => $_,
                        ngram   => $a{ngram} // $DEFAULT_NGRAM,
                    ),
                } }
                @{ string2sentences( string => $d{text}) }
            ];
        }
        else {
            $d{shingles}            = string2shingles(
                string  => $d{text},
                ngram   => $a{ngram} // $DEFAULT_NGRAM,
            );

            if($a{shingles_prepare}) {
                $d{shingles_prepared}   = prepare_set4jaccard_coefficient(
                    set => $d{shingles},
                );
            }
        }
    }

    # TODO more preparations

    \%d;
}

=head2 plagiarism_prepare_text

It prepares text:

=over

=item lowercase

=item remove non-word stuff (digits too)

=item normalize spaces

=item stemming L<wiki stemming|https://en.wikipedia.org/wiki/Stemming>, L<Lingua::Stem>

=item TODO dictionary checks: 1 letter typos (levenshtein distance is 1 (?)), unknown -> <unknown>
  not levenshtein, but only remove/add operations are allowed. it's lcs - longest common string
  Sequence comparison
=item TODO as one of approaches identify change seldomly used words with <seldom>

=back

=cut

sub plagiarism_prepare_text {
    my %a   = (
        text    => undef,
        @_
    );

    my $s   = lc $a{text};

    # non alphanumerical and dots
    # dots to preserve sentences
    $s      =~ s#[^\w\.]+# #g;
    # separate numbers
    $s      =~ s#\b\d+\b# #g;
    # small words
    $s      =~ s#\b\w{1,2}\b# #g;
    # the
    $s      =~ s#\bthe\b# #g;
    # sequences of dots
    $s      =~ s#\.{2,}#.#g;
    # spaces before dot
    $s      =~ s#\s+\.#.#g;
    # sequences of spaces
    $s      =~ s#\s{2,}# #g;
    # starting/ending spaces
    $s      =~ s#(?:^\s+|\s+$)##g;

    my @words;
    my $stem    = Lingua::Stem->new({ -locale => 'en-us' });
    foreach my $word (split /\s+/, $s) {
        my $dot = '';
        if($word =~ /\.$/) {
            $dot    = '.';
        }

        $stem->stem_in_place($word);

        push @words, "$word$dot";
    }
    $s  = join ' ', @words;

    {
        text    => $s,
    };
}

# TODO docs for following result_sentence_measure_* functions:

sub result_sentence_measure_avg {
    my %a   = (
        sentences   => [],
        @_
    );
    return 0    unless scalar @{ $a{sentences} };

    my $s   = 0;
    foreach(@{ $a{sentences} }) {
        $s  += $_->{plagiarism_measure};
    }
    $s / scalar(@{ $a{sentences} });
}

sub result_sentence_measure_weighted {
    my %a   = (
        sentences   => [],
        ngram       => $DEFAULT_NGRAM,
        @_
    );
    my $n_sentences = scalar @{ $a{sentences} };
    return 0    unless $n_sentences;

    my $sentences_length = 0;
    foreach(@{ $a{sentences} }) {
        $sentences_length    += scalar( @{ $_->{shingles} } ) + $a{ngram};
    }

    my $s   = 0;
    foreach(@{ $a{sentences} }) {
        my $sentence_length = scalar( @{ $_->{shingles} } ) + $a{ngram};
        $s  += $_->{plagiarism_measure} * ($sentence_length / $sentences_length);
    }
    $s;
}

sub result_sentence_measure_avg_derived_sentences {
    my %a   = (
        sentences   => [],
        ngram       => $DEFAULT_NGRAM,
        @_
    );
    my $n_sentences = scalar @{ $a{sentences} };
    return 0    unless $n_sentences;

    my $n_derived_sentences = 0;
    foreach(@{ $a{sentences} }) {
        $n_derived_sentences++
            if .5 <= $_->{plagiarism_measure};
    }

    $n_derived_sentences / $n_sentences;
}

=head2 plagiarism_measure

Measures how much 1st text is a plagiarization of 2nd one.

=over

=item TODO paraphrase acquisition

=back

Returns:

=over

=item $SENTENCE_IDENTICAL    - the two documents are identical, possibly except for minor edits; neither is a complete subset of the other;

=item $SENTENCE_MAJOR_OVERLAP- there is sufficient overlap between (parts of) the two documents that there must have been common source material - for example, statement of identical numeric facts that would not be common knowledge, drawn from (for example) a press release;

=item $SENTENCE_MINOR_OVERLAP- there is some overlap between (parts of) the two documents, but not enough to conclude that the two authors had shared common source material - for example, because the shared content is "common knowledge";

=item $SENTENCE_UNRELATED    - there is no overlap between the two documents, and they are completely dissimilar.

=back

=cut

sub plagiarism_measure {
    my %a   = (
        query_text                          => undef,
        query_data                          => undef,
        document_text                       => undef,
        document_data                       => undef,
        # TODO describe following parameters in docs above:
        ngram                               => $DEFAULT_NGRAM,
        min_sentence_length                 => $DEFAULT_MIN_SENTENCE_LENGTH,
        # can be a string with function name or a callback
        result_sentence_measure_function    => \&result_sentence_measure_weighted,
        @_
    );

    return 0    unless defined $a{query_text};
    return 0    unless defined $a{document_text};

    my %query_data          = %{ $a{query_data} // {} };
    if(
        !$a{query_data}->{text}
        ||
        !$a{query_data}->{sentences}
    ) {
        %query_data = (
            %query_data,
            %{ plagiarism_prepare(
                text        => $a{query_text},
                sentences   => 1,
            ) },
        );
    }

    my $query_text          = $query_data{text};
    my @query_sentences     = @{ $query_data{sentences} // [] };

    my %document_data       = %{ $a{document_data} // {} };
    if(
        !$a{document_data}->{text}
        ||
        !$a{document_data}->{shingles_analyzed}
    ) {
        %document_data = (
            %document_data,
            %{ plagiarism_prepare(
                text                => $a{document_text},
                sentences           => 0,
                shingles_prepare    => 1,
            ) },
        );
    }
    my %document_shingles   = %{ $document_data{shingles_prepared} // {} };

    my $r;
    foreach my $sentence (@query_sentences) {
        if(defined $a{min_sentence_length}) {
            if(scalar(@{ $sentence->{shingles} // [] }) + $a{ngram} - 1 < $a{min_sentence_length}) {
                next;
            }
        }

        $sentence->{plagiarism_measure}   = jaccard_coefficient2(
            set0    => $sentence->{shingles},
            set1    => \%document_shingles,
        );
    }

    call_function(
        $a{result_sentence_measure_function},
        ngram       => $a{ngram},
        sentences   => \@query_sentences,
    );
}

sub call_function {
    my $f   = shift;

    if('CODE' eq ref $f) {
        return $f->(@_);
    }
    elsif(__PACKAGE__->can($f)) {
        my $ff  = __PACKAGE__."::$f";
        no strict 'refs';
        return &$ff(@_);
    }

    say Dumper($f);
    die "not a function reference and not function of this module";
}

# DEBUG
# =head2 plagiarise_measure_sentence
# 
# Measures how much query sentence is a plagiarisation of document's one
# 
# =for comment
# TODO
# Using the METER corpus described in section 2.1., according to which a newspaper
# text is classified as to whether it is wholly derived, partially derived or non-derived from
# a newswire source, Clough/Gaizauskas/Piao (2002) have investigated three computa-
# tional techniques for identifying text re-use automatically: n-gram matching (section
# 3.2.2.), sequence comparison (section 3.2.3.) and sentence alignment (section 3.2.4.). In
# the first approach, n-gram matches of varying lengths were used together with a contain-
# ment score (Broder 1998); in the second a substring matching algorithm called Greedy
# String Tiling (Wise 1993) was used to compute the longest possible substrings between
# newswire-newspaper pairs; and in the final approach sentences between the source and
# candidate text pairs were automatically aligned.
# =end
# 
# Returns:
# 
# =over
# 
# =item $SENTENCE_EXACT_MATCH      - exact match
# 
# =item $SENTENCE_MINOR_REVISION   - minor revision
# 
# =item $SENTENCE_MAJOR_REVISION   - major revision
# 
# =item $SENTENCE_SPECIFIC_TOPIC   - specific topic
# 
# =item $SENTENCE_GENERAL_TOPIC    - general topic
# 
# =item $SENTENCE_UNRELATED        - unrelated
# 
# =back
# 
# =cut
# 
# sub plagiarise_measure_sentence {
#     my %a   = (
#         query_sentence      => undef,
#         query_data          => {},
#         candidate_sentence  => undef,
#         candidate_data      => {},
#         @_
#     );
# 
#     undef;
# }
# 
=head2 measure2number

Converts measure from plagiarise_measure* routines to a number from range [0,1].

=cut

sub measure2number { 1*$_[0] }

=head2 measure2number

Converts measure from plagiarise_measure* routines to a string if possible

=cut

sub measure2string {
    my $m   = shift;
    my $n   = measure2number($m);
    $m      =~ s/^$n\s*//;
    $m // '';
}

=head2 string2sentences

Split string into sentences.

Intput parameters (as hash keys):

=over

=item string - string to parse, has to be prepare with plagiarism_prepare_text.

=back

=cut

sub string2sentences {
    my %a   = (
        string      => undef,
        @_
    );

    [ grep {length} split /\s*\.\s*/, $a{string} ];
}

=head2 string2shingles

Create shingles from text.

Intput parameters (as hash keys):

=over

=item string - string to parse, has to be prepare with plagiarism_prepare_text.

=item n - shingle is n-gram, n. recommended values are 2,3,4. default is 2.

=back

=cut

sub string2shingles {
    my %a   = (
        string      => undef,
        ngram       => $DEFAULT_NGRAM,
        @_
    );

    # remove dots
    $a{string}  =~ s/\s*\.\s*/ /g;
    $a{string}  =~ s/(?:^\s+|\s+$)//;

    my @words   = split /\s+/, $a{string};

    my @shingles;
    # leave the case #@words < $a{ngram}
    # we don't match too small sentences or texts
    my $n1  = $a{ngram} - 1;
    foreach(my $i=$n1; $i<@words; $i++) {
        push @shingles, join ' ', @words[ ($i-$n1) .. $i ];
    }

    \@shingles;
}

=head2 prepare_set4jaccard_coefficient

Prepare data structure for quick jaccard_coefficient calculation

Intput parameters (as hash keys):

=over

=item set - [ shingle0, shingle1, ... ]

=back

Return value:

    {
        shingle0    => times_it_meets_in_text0,
        shingle1    => times_it_meets_in_text0,
        ...
    }

=cut

sub prepare_set4jaccard_coefficient {
    my %a   = (
        set     => [],
        @_
    );

    my %r;
    foreach(@{ $a{set} }) {
        $r{ $_ }++;
    }

    \%r;
}

=head2 jaccard_coefficient

Calculates Jaccard's coefficient for 2 given sets:

    J(S0, S1) = |S0 ∩ S1| / |S0 ∪ S1| = |S0 intersection S1| / |S0 union S1|

where |S| - number of elements in finite set S

Intput parameters (as hash keys):

=over

=item set0 - [ shingle0, shingle1, ... ]

=item set1 - [ shingle0, shingle1, ... ]

=back

For quicker result set1 can be given prepared with prepare_set4jaccard_coefficient. It has to be in the following form:

    {
        shingle0    => times_it_meets_in_text0,
        shingle1    => times_it_meets_in_text0,
        ...
    }

=cut

sub jaccard_coefficient {
    my %a   = (
        set0    => [],
        set1    => [],
        @_
    );

    my %set1;
    if('ARRAY' eq ref $a{set1}) {
        %set1   = %{ prepare_set4jaccard_coefficient(
            set => $a{set1},
        ) };
    }
    else {
        %set1   = %{ $a{set1} };
    }

    my (%set0, %in_both);
    foreach(@{ $a{set0} }) {
        $set0{$_}++;
        if(exists $set1{$_}) {
            $in_both{$_}++;
        }
    }

    return scalar( keys %in_both ) / (scalar(keys %set0) + scalar(keys %set1) - scalar(keys %in_both));
}

=head2 jaccard_coefficient2

Calculates Jaccard's coefficient for 2 given sets:

    J(S0, S1) = |S0 ∩ S1| / |S0| = |S0 intersection S1| / |S0|

where |S| - number of elements in finite set S

Intput parameters (as hash keys):

=over

=item set0 - [ shingle0, shingle1, ... ]

=item set1 - [ shingle0, shingle1, ... ]

=back

For quicker result set1 can be given prepared with prepare_set4jaccard_coefficient. It has to be in the following form:

    {
        shingle0    => times_it_meets_in_text0,
        shingle1    => times_it_meets_in_text0,
        ...
    }

=cut

sub jaccard_coefficient2 {
    my %a   = (
        set0    => [],
        set1    => [],
        @_
    );

    my %set1;
    if('ARRAY' eq ref $a{set1}) {
        %set1   = %{ prepare_set4jaccard_coefficient(
            set => $a{set1},
        ) };
    }
    else {
        %set1   = %{ $a{set1} };
    }

    my (%set0, %in_both);
    foreach(@{ $a{set0} }) {
        $set0{$_}++;
        if(exists $set1{$_}) {
            $in_both{$_}++;
        }
    }

    return scalar(keys %in_both) / scalar(keys %set0);
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
