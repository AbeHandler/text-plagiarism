#!/usr/bin/env perl
use common::sense;
use Test::More qw(no_plan);

BEGIN {
    use_ok( 'Text::Plagiarism' ) || print "Bail out!\n";
}

diag( "Testing Text::Plagiarism $Text::Plagiarism::VERSION, Perl $], $^X" );
