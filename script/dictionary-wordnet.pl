#!/usr/bin/env perl 
use common::sense;
use lib qw(lib);
use Readonly;
use Data::Dumper;
use File::Copy;
use Text::Plagiarism qw(plagiarism_prepare_text);

Readonly    our $DICTIONARY_DIR             => 'dictionary';
Readonly    our $DICTIONARY_FILE            => "$DICTIONARY_DIR/words.txt";
Readonly    our $DICTIONARY_FILE_TMP        => "$DICTIONARY_DIR/words.txt.tmp";
Readonly    our $WORDNET_DIR                => "$DICTIONARY_DIR/wordnet";
Readonly    our $GLOSSARY_DIR               => "$WORDNET_DIR/WordNet-3.0/glosstag";
Readonly    our $MERGED_DIR                 => "$GLOSSARY_DIR/merged";

system "touch $DICTIONARY_FILE";
copy($DICTIONARY_FILE, $DICTIONARY_FILE_TMP)    or die "Copy failed: $!";

my $processed   = 0;
foreach my $file (glob "$MERGED_DIR/*.xml") {
    say "processing file '$file'";
    process_file(file => $file);
    $processed++;
}

if($processed) {
    system "sort $DICTIONARY_FILE_TMP | uniq > $DICTIONARY_FILE";
}
unlink $DICTIONARY_FILE_TMP;

sub process_file {
    my %a   = (
        file    => undef,
        @_
    );

    open(IN, '<', $a{file}) or die "can't open '$a{file}': $!";
    open(OUT, '>>', $DICTIONARY_FILE_TMP) or die "can't open '$DICTIONARY_FILE_TMP': $!";
    while(<IN>) {
        next    unless m#<term>(.+)</term>#;
        my $term    = $1;
        $term       =~ s/(^\s+|\s+$)//g;
        my $d       = plagiarism_prepare_text(text => $term);
        my @words   = grep { '.' ne $_ && !/^\s*$/}
            split /\s+/, $d->{text}
        ;
        next    unless @words;
        say OUT join "\n", @words;
    }
}
