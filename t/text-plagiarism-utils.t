#!/usr/bin/env perl
use common::sense;
use Test::More qw(no_plan);
use Test::Differences;
use Readonly;
use Getopt::Long;
use Data::Dumper;

BEGIN {
    use_ok( 'Text::Plagiarism::Utils', qw(
        module2path
        module_base_dir
    ) )
        or die "Bail out, main module can't be used!";
}

my $f   = module2path();
is($f, 'Text/Plagiarism/Utils.pm', "module2path");

my $d   = module_base_dir();
ok(-d $d, "module_base_dir");
ok(-f "$d/lib/Text/Plagiarism.pm" || -f "$d/Text/Plagiarism.pm", "module_base_dir main module");
