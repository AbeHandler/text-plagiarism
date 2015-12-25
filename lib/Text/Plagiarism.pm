package Text::Plagiarism;
use common::sense;
use Exporter::Easy (
    EXPORT  => [qw(
        plagiarism_prepare
        plagiarism_prepare_text
        plagiarism_measure
        plagiarism_measure_sentence
    )],
);
use Readonly;
use Lingua::Stem;
use Data::Dumper;
use Text::Plagiarism::Utils qw(module_base_dir);
use Text::Plagiarism::SynSet::Config qw(synset_load);

=encoding utf8

=cut

Readonly our $DEFAULT_NGRAM                             => 2;
Readonly our $DEFAULT_MIN_SENTENCE_LENGTH               => 1;

Readonly our $DICTIONARY_FILE            => 'dictionary/words.txt';
Readonly our $STOP_LIST_FILE             => 'dictionary/stop-list.txt';
Readonly our $WORD_UNKNOWN               => '<unk>';
Readonly our $WORD_DOT                   => '.';
Readonly our $WORD_SELDOM                => '<seldom>';
# occurrences <= threshold
Readonly our $WORD_SELDOM_THRESHOLD      => 1;

=head1 NAME

Text::Plagiarism - modules checks plagirism in texts

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Allow you to measure how much are 2 sentences/documents are identical.

    use Text::Plagiarism qw(plagiarism_measure);

    my $m   = plagiarism_measure(
        query_text      => 'TEXT',
        document_text   => 'TEXT',
    );
    print "plagiarism measure: $m from range [0,1]\n"

TODO more code snippets?

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
        use_dictionary      => 1,
        use_synsets         => 0,
        use_seldom_words    => 0,
        @_
    );

    my %d   = %{ plagiarism_prepare_text(%a) // {} };

    if(defined $a{sentences}) {
        if($a{sentences}) {
            $d{sentences}   = [
                map { {
                    words       => $_,
                    shingles    => words2shingles(
                        words   => $_,
                        ngram   => $a{ngram} // $DEFAULT_NGRAM,
                    ),
                } }
                @{ words2sentences( words => $d{words}) }
            ];
        }
        else {
            $d{shingles}            = words2shingles(
                words   => $d{words},
                ngram   => $a{ngram} // $DEFAULT_NGRAM,
            );

            if($a{shingles_prepare}) {
                $d{shingles_prepared}   = prepare_set4jaccard_coefficient(
                    set => $d{shingles},
                );
            }
        }
    }

    \%d;
}

=head2 plagiarism_prepare_text

It prepares text:

=over

=item lowercase

=item remove non-word stuff (digits too)

=item normalize spaces

=item spell checker

=over

=item not implemented. Because it's ~3% of unknown words for wordsnet dictionary in METER corpus. And only some part of it is real typos (most probably small part). It won't give a lot of burst. This idea at least delayed.

=item how to make it - L<http://norvig.com/spell-correct.html>, and how to make it really quick - L<http://blog.faroo.com/2012/06/07/improved-edit-distance-based-spelling-correction/>

=back

=item dictionary - checks words against dictionary, change all unknown to special tag ($WORD_UNKNOWN)

=item stemming L<wiki stemming|https://en.wikipedia.org/wiki/Stemming>, L<Lingua::Stem>

=back

=cut

sub plagiarism_prepare_text {
    my %a   = (
        text            => undef,
        use_dictionary  => 1,
        use_synsets     => 0,
        use_seldom_words=> 0,
        use_stop_list   => 1,
        @_
    );

    my $s   = lc $a{text};

    # non alphanumerical and dots
    # dots to preserve sentences
    # save ', it's part of the words
    # 've, 's, 'll and co will be removed with stop list word if used
    $s      =~ s#[^\w\.']+# #g;
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

    my @words_r;
    my $stem    = Lingua::Stem->new({ -locale => 'en-us' });
    my @words   = split /\s+/, $s;
    my %words;
    for(my $i=0; $i<@words; $i++) {
        my $word    = $words[$i];
        my $dot = '';
        if($word =~ /\.$/) {
            $dot    = '.';
            $word   =~ s/\.$//;
        }

        if($a{use_stop_list}) {
            if(load_stop_list()->{$word}) {
                push @words_r, $dot if $dot;
                next;
            }
        }

        $stem->stem_in_place($word);

        if($a{use_dictionary}) {
            my $r   = dictionary_fix_word(
                word    => $word,
            );
            $word   = $r->{word} // $word;
        }

        if($WORD_DOT ne $word) {
            $words{$word}   //= 0;
            $words{$word}   ++;
        }

        push @words_r, $word;
        push @words_r, $dot if $dot;
    }

    for(my $i=0; $i<@words_r; $i++) {
        my $word    = $words_r[$i];
        if($WORD_DOT ne $word) {
            if($words{$word} <= $WORD_SELDOM_THRESHOLD) {
                $words_r[$i]    = $WORD_SELDOM;
            }
        }
    }

    if($a{use_synsets}) {
        for(my $i=0; $i<@words_r; $i++) {
            my $word    = $words_r[$i];

            next    if $WORD_DOT eq $word;

            my @words_after = $i < $#words_r ? @words_r[($i+1) .. $#words_r ] : ();

            my $r   = word2synset(
                word        => $word,
                words_after => \@words_after,
            );
            $words_r[$i]   = $r->{synset}    if $r->{synset};
        }
    }

    {
        words   => \@words_r,
    };
}

=head2 load_dictionary

Loads dictionary.

Returns:

    {
        word0   => 1,
        ...
    }

=cut

sub load_dictionary {
    state $dict;
    unless(defined $dict) {
        my $path    = module_base_dir();
        $path       .= "/$DICTIONARY_FILE";

        open(DICT, '<', $path) or die "can't open dictionary file '$path': $!";
        while(<DICT>) {
            chomp;
            $dict->{$_}   = 1;
        }
        close DICT;
    }
    $dict;
}

=head2 dictionary_fix_word

Change the word according to the dictionary

Parameters:

=over

=item word => 'STRING'

=back

Returns:

    {
        word   => "FIXED_WORD",
    }

=cut

sub dictionary_fix_word {
    my %a   = (
        word    => undef,
        @_
    );
    my $word;

    my $dictionary  = load_dictionary();

    if($dictionary->{$a{word}}) {
        $word   = $a{word};
    }
    else {
        $word   = $WORD_UNKNOWN;
    }

    {
        word    => $word,
    };
}

=head2 load_stop_list

Loads stop list data.

Returns:

    {
        word0   => 1,
        ...
    }

=cut

sub load_stop_list {
    state $stop_list;
    unless(defined $stop_list) {
        my $path    = module_base_dir();
        $path       .= "/$STOP_LIST_FILE";

        open(IN, '<', $path) or die "can't open stop list file '$path': $!";
        while(<IN>) {
            chomp;
            $stop_list->{$_}   = 1;
        }
        close IN;
    }
    $stop_list;
}

=head2 load_synsets

Loads synsets DB.

Returns:

    {
        'first_word_in_terms_for_synset'   => {
            key => {
                term    => 'full term'
                synset_ids  => [
                    'list of possible ids for this full term',
                    ...
                ],
            },
            ...
        }
    }

=cut

sub load_synsets {
    state $synsets;
    unless(defined $synsets) {
        my $synsets_direct    = synset_load();

        # create help structure for search
        while(my($synset_id, $terms) = each %$synsets_direct) {
            foreach my $term (@$terms) {
                if(ref $term) {
                    my $key = join ' ', @$term;
                    $synsets->{ $term->[0] }->{$key}->{term}        //= $term;
                    push @{ $synsets->{ $term->[0] }->{$key}->{synset_ids} }, $synset_id;
                }
                else {
                    $synsets->{ $term }->{$term}->{term}        //= [$term];
                    push @{ $synsets->{ $term }->{$term}->{synset_ids} }, $synset_id;
                }
            }
        }
    }
    $synsets;
}

=head2 word2synset

Change word on synset id or possible array reference of synset ids

Input parameters:

=over

=item word => 'WORD'

=item words_after => [qw(possible words after for terms match)]

=back

Returns:

    {
        synset  => [
            'possible synset IDS',
            ...
        ],
    }

=cut

sub word2synset {
    my %a   = (
        word        => undef,
        words_after => [],
        @_
    );
    my $word;

    my $synsets = load_synsets();
    my @words   = ($a{word}, @{ $a{words_after} // [] });

    if($synsets->{$a{word}}) {
        my %synsets = %{ $synsets->{$a{word}} };
        my @variants;
        while(my($key, $v) = each %synsets) {
            my @term    = @{ $v->{term} };
            # not enough words for term
            continue    if @words < @term;
            if(@words[0 .. $#term] ~~ @term) {
                push @variants, @{ $v->{synset_ids} };
            }
        }
        
        if(@variants) {
            if(1 == @variants) {
                $word   = $variants[0];
            }
            else {
                $word   = [@variants];
            }
        }
    }

    {
        synset  => $word,
    };
}

=head2 result_sentence_measure_max_avg

One of the possible functions to calculate result plagiarism measure with given sentences measures.

Average of given values using only some part of maximum values.

Input parameters:

=over

=item sentences => [sentence0_measure, ... ]

=item max_ratio => R, R is from range [0,1]. It's ratio of the given sentences to use only maximum measure from it.

=item max_absolute => N, use only N maximum (in measure) sentences.

=back

Returns:

    measure in range [0,1]

=cut

sub result_sentence_measure_max_avg {
    my %a   = (
        sentences       => [],
        max_ratio       => 1.0,
        #max_absolute    => 3,
        @_
    );
    return 0    unless scalar @{ $a{sentences} };

    my @sorted  = sort {
        $b->{plagiarism_measure} <=> $a->{plagiarism_measure}
    }
        @{ $a{sentences} };

    my $max_idx = defined $a{max_absolute} ?
        $a{max_absolute} - 1 :
        int( $a{max_ratio} * scalar(@{ $a{sentences} }) ) - 1 ;
    $max_idx    = 0     if $max_idx < 0;

    my $s   = 0;
    for(my $i=0; $i<$max_idx; $i++) {
        my $sentence    = $sorted[$i];
        $s  += $sentence->{plagiarism_measure};
    }

    $s / scalar(@{ $a{sentences} });
}

=head2 result_sentence_measure_avg

One of the possible functions to calculate result plagiarism measure with given sentences measures.

Simple average value of the given values.

Input parameters:

=over

=item sentences => [sentence0_measure, ... ]

=back

Returns:

    measure in range [0,1]

=cut

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

=head2 result_sentence_measure_weighted

One of the possible functions to calculate result plagiarism measure with given sentences measures.

Calculates average using weighted sentene measure. Weight is proportional to the length of the sentece.

Input parameters:

=over

=item sentences => [sentence0_measure, ... ]

=back

Returns:

    measure in range [0,1]

=cut

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

=head2 result_sentence_measure_avg_derived_sentences

One of the possible functions to calculate result plagiarism measure with given sentences measures.

Calculates average of only measure > 0.5

Input parameters:

=over

=item sentences => [sentence0_measure, ... ]

=back

Returns:

    measure in range [0,1]

=cut
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

Input parameters:

=over

=item query_text => 'TEXT'

=item query_data => DATA, can be prepared with plagiarism_prepare for saving time

=item document_text => 'TEXT'

=item document_data => DATA, can be prepared with plagiarism_prepare for saving time

=item ngram => N, n from n-gram (aka shingles), default $DEFAULT_NGRAM

=item min_sentence_length => LENGTH, sentence less than this limit are filterd, default $DEFAULT_MIN_SENTENCE_LENGTH,

=item result_sentence_measure_function => CALLBACK_OR_FUNCTION_NAME, function for result measure calculation from sentenses measures, default \&result_sentence_measure_weighted,

=item use_dictionary => 0|1, flag for dictionary usage, default 1

=item use_synsets => 0|1, flag for synset usage, default 0

=item use_seldom_words=> 0|1, flag for seldom words usage, default 0,

=item use_stop_list => 0|1, flag for stop list filter, default 1,

=back

TODO stoplist meter_corpus/frequency_lists/EnglishStopList

Returns:

    R in range [0,1]

=cut

sub plagiarism_measure {
    my %a   = (
        query_text                          => undef,
        query_data                          => undef,
        document_text                       => undef,
        document_data                       => undef,
        ngram                               => $DEFAULT_NGRAM,
        min_sentence_length                 => $DEFAULT_MIN_SENTENCE_LENGTH,
        # can be a string with function name or a callback
        result_sentence_measure_function    => \&result_sentence_measure_weighted,
        use_dictionary                      => 1,
        use_synsets                         => 0,
        use_seldom_words                    => 0,
        use_stop_list                       => 1,
        @_
    );

    return 0    unless defined $a{query_text};
    return 0    unless defined $a{document_text};

    my %query_data          = %{ $a{query_data} // {} };
    if(
        !$a{query_data}->{words}
        ||
        !$a{query_data}->{sentences}
    ) {
        %query_data = (
            %query_data,
            %{ plagiarism_prepare(
                text                => $a{query_text},
                sentences           => 1,
                use_dictionary      => $a{use_dictionary},
                use_synsets         => $a{use_synsets},
                use_seldom_words    => $a{use_seldom_words},
                use_stop_list       => $a{use_stop_list},
            ) },
        );
    }

    my $query_text          = $query_data{text};
    my @query_sentences     = @{ $query_data{sentences} // [] };

    my %document_data       = %{ $a{document_data} // {} };
    if(
        !$a{document_data}->{words}
        ||
        !$a{document_data}->{shingles_prepared}
    ) {
        %document_data = (
            %document_data,
            %{ plagiarism_prepare(
                text                => $a{document_text},
                sentences           => 0,
                shingles_prepare    => 1,
                use_dictionary      => $a{use_dictionary},
                use_synsets         => $a{use_synsets},
                use_seldom_words    => $a{use_seldom_words},
                use_stop_list       => $a{use_stop_list},
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

    die "not a function reference and not function of this module:\n".Dumper($f);
}

=head2 words2sentences

Split words into sentences.

Input parameters (as hash keys):

=over

=item words - words to split, has to be prepared with plagiarism_prepare_text.

=back

Return parameter:

    [
        [qw(the first sentence)],
        [qw(the second one)],
    ]

=cut

sub words2sentences {
    my %a   = (
        words      => undef,
        @_
    );

    my (@r, @s);
    foreach(@{ $a{words} // [] }) {
        if('.' eq $_) {
            push @r, [@s];
            @s  = ();
        }
        else {
            push @s, $_;
        }
    }
    push @r, [@s]   if @s;

    [ @r ];
}

=head2 words2shingles

Create shingles from words.

Input parameters (as hash keys):

=over

=item words - words to parse, has to be prepared with plagiarism_prepare_text.

=item n - shingle is n-gram, n. recommended values are 2,3,4. default is 2.

=back

Return parameter:

    [
        'shingle0',
        [qw(set of possible shingles from given synsets instead of a single word)],
        ...
    ]

=cut

sub words2shingles {
    my %a   = (
        words       => [],
        ngram       => $DEFAULT_NGRAM,
        @_
    );

    # remove dots
    my @words   = grep {'.' ne $_} @{ $a{words} };

    my @shingles;
    # leave the case #@words < $a{ngram}
    # we don't match too small sentences or texts
    my $n1  = $a{ngram} - 1;
    foreach(my $i=$n1; $i<@words; $i++) {
        my @combs   = map { join ' ', @$_ }
            @{ combinations( sets => [
                map { ref $_ ? $_ : [$_] }
                @words[ ($i-$n1) .. $i ]
            ] ) };
        if(1 == @combs) {
            push @shingles, $combs[0];
        }
        else {
            push @shingles, [@combs];
        }
    }

    \@shingles;
}

=head2 combinations

Creates possible combinations from given sets.

=over

=item sets => [[qw(set0)], ... ] - sets to construct result from

=back

Return parameter:

    [
        ['element from set0', 'element from set1', ...],
        ...
    ]

=cut

sub combinations {
    my %a   = (
        sets    => [],
        set_idx => 0,
        set_cur => [],
        @_
    );
    return []   unless @{ $a{sets} };
    return [$a{set_cur}]
        if $a{set_idx} >= @{ $a{sets} };

    my @r;
    foreach(@{ $a{sets}->[$a{set_idx}] }) {
        push @r, @{ combinations(
            sets    => $a{sets},
            set_idx => $a{set_idx} + 1,
            set_cur => [@{ $a{set_cur} }, $_],
        ) };
    }

    \@r;
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
        if(ref $_) {
            foreach(@$_) {
                $r{ $_ }++;
            }
        }
        else {
            $r{ $_ }++;
        }
    }

    \%r;
}

=head2 jaccard_coefficient

Calculates Jaccard's coefficient for 2 given sets:

    J(S0, S1) = |S0 ∩ S1| / |S0 ∪ S1| = |S0 intersection S1| / |S0 union S1|

where |S| - number of elements in finite set S

Intput parameters (as hash keys):

=over

=item set0 - [ 'shingle0', [qw(or set of shingles)], ... ]

=item set1 - [ 'shingle0', [qw(or set of shingles)], ... ]

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
    return 0    unless @{ $a{set0} };

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
        if(ref $_) {
            my $found   = 0;
            foreach(@$_) {
                if(exists $set1{$_}) {
                    # count each synonym in both in_both and set0
                    $found  = 1;
                    $set0{$_}++;
                    $in_both{$_}++;
                }
            }

            unless($found) {
                # not found for any of synset words
                $set0{join(" ", @$_)}++;
            }
        }
        else {
            $set0{$_}++;
            if(exists $set1{$_}) {
                $in_both{$_}++;
            }
        }
    }

    # we don't re-calculate # of keys in %set0
    # because each each synset is treated as single word
    # if synset gives us more than 1 occurrence in %in_both
    # => it means that text is more similar to each other
    return scalar( keys %in_both ) / (scalar(keys %set0) + scalar(keys %set1) - scalar(keys %in_both));
}

=head2 jaccard_coefficient2

Calculates Jaccard's coefficient for 2 given sets:

    J(S0, S1) = |S0 ∩ S1| / |S0| = |S0 intersection S1| / |S0|

where |S| - number of elements in finite set S

Intput parameters (as hash keys):

=over

=item set0 - [ 'shingle0', [qw(or set of shingles)], ... ]

=item set1 - [ 'shingle0', [qw(or set of shingles)], ... ]

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
    return 0    unless @{ $a{set0} };

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
        if(ref $_) {
            my $found   = 0;
            foreach(@$_) {
                if(exists $set1{$_}) {
                    # count each synonym in both in_both and set0
                    $found  = 1;
                    $set0{$_}++;
                    $in_both{$_}++;
                }
            }

            unless($found) {
                # not found for any of synset words
                $set0{join(" ", @$_)}++;
            }
        }
        else {
            $set0{$_}++;
            if(exists $set1{$_}) {
                $in_both{$_}++;
            }
        }
    }

    # we don't re-calculate # of keys in %set0
    # because each each synset is treated as single word
    # if synset gives us more than 1 occurrence in %in_both
    # => it means that text is more similar to each other
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

Thanks Princeton for L<WordNet database|http://wordnet.princeton.edu/wordnet> database:

George A. Miller (1995). WordNet: A Lexical Database for English.
Communications of the ACM Vol. 38, No. 11: 39-41.

Christiane Fellbaum (1998, ed.) WordNet: An Electronic Lexical Database. Cambridge, MA: MIT Press.

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
