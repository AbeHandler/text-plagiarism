#!/usr/bin/env perl
use common::sense;
use Test::More qw(no_plan);
use Test::Differences;
use Readonly;
use Getopt::Long;
use Data::Dumper;

BEGIN {
    use_ok( 'Text::Plagiarism::SynSet::Config', qw(
        synset_file
        synset_load
    ) )
        or die "Bail out, main module can't be used!";
}

my $f   = synset_file();
like($f, qr#dictionary/synset\.txt#, "synset file");

my $synsets = synset_load();
is(ref $synsets, 'HASH', "synsets data is hash ref");
