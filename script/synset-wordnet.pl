#!/usr/bin/env perl 
use common::sense;
use lib qw(lib);
use Readonly;
use Data::Dumper;
use File::Copy;
use Text::Plagiarism qw(plagiarism_prepare_text);
use Text::Plagiarism::SynSet::Config qw(synset_open synset_save);
use XML::Parser;
use List::MoreUtils qw(uniq);

$|  = 1;

Readonly    our $SYNSET_DIR                 => 'dictionary';
Readonly    our $SYNSET_FILE                => "$SYNSET_DIR/synset.txt";
Readonly    our $WORDNET_DIR                => "$SYNSET_DIR/wordnet";
Readonly    our $GLOSSARY_DIR               => "$WORDNET_DIR/WordNet-3.0/glosstag";
Readonly    our $MERGED_DIR                 => "$GLOSSARY_DIR/merged";

system "touch $SYNSET_FILE";

my $processed   = 0;
my %synsets;
foreach my $file (glob "$MERGED_DIR/*.xml") {
    say "processing file '$file'";
    process_file(file => $file);
    $processed++;
    # DEBUG
    #last;
}

if($processed) {
    synset_save(
        synsets => \%synsets,
    );
}

sub process_file {
    my %a   = (
        file    => undef,
        @_
    );

    my ($synset, $terms_tag, $term_tag, @terms);
    my $n_processed = 0;
    my $n           = `grep -c '<synset' $a{file}`;
    chomp $n;

    # Alternative
    my $xml_parser  = XML::Parser->new(
        Handlers    => {
            Start   => sub {
                my ($expat, $el, %attrs)    = @_;
                given($el) {
                    when('synset') {
                        $synset = \%attrs;
                    }
                    when('terms') {
                        $terms_tag = 1;
                    }
                    when('term') {
                        $term_tag = 1   if $terms_tag;
                    }
                }
                #say Dumper('start',$el, \%attrs);
            },
            End     => sub {
                my ($expat, $el)    = @_;
                given($el) {
                    when('term') {
                        $term_tag = 0   if $term_tag;
                    }
                    when('terms') {
                        $terms_tag = 0  if $terms_tag;
                        $term_tag = 0   if $term_tag;
                    }
                    when('synset') {
                        my @terms_prepared  = uniq sort
                            map {
                                my $term    = $_;
                                my @words   = grep {
                                        length
                                        &&
                                        $Text::Plagiarism::WORD_DOT ne $_
                                    }
                                    grep { length }
                                    map {
                                        my $d   = plagiarism_prepare_text(text => $_);
                                        @{ $d->{words} };
                                    } 
                                    split /\s+/, $term;
                                @words && !($Text::Plagiarism::WORD_UNKNOWN ~~ @words) ? (join(' ', @words)) : ();
                            }
                            @terms;

                        if(@terms_prepared) {
                            my $synset_id   = $synset->{id};
                            #say Dumper($synset_id,\@terms,\@terms_prepared);
                            if(exists $synsets{$synset_id}) {
                                $synsets{$synset_id}    = [uniq sort @{ $synsets{$synset_id} // [] }, @terms_prepared];
                            }
                            else {
                                $synsets{$synset_id}    = [@terms_prepared];
                            }
                            $n_processed++;
                            if(0 == $n_processed % 1_000) {
                                printf "#processed %06d / %06d = %02d%%\n", $n_processed, $n, int(100*$n_processed/$n);
                            }
                            #say Dumper($synset_id,$synsets{$synset_id},\@terms,\@terms_prepared);
                        }

                        @terms  = ();
                        $term_tag = 0   if $term_tag;
                        $terms_tag = 0  if $terms_tag;
                        $synset = undef;
                    }
                }
                #say Dumper('end',$el);
            },
            Char    => sub {
                my ($expat, @ar)    = @_;
                if($term_tag) {
                    push @terms, @ar;
                }
                #say Dumper('char',\@ar);
            },
        },
    );
    $xml_parser->parsefile($a{file});
}

#synset_open synset_append
