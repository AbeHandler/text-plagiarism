#!/usr/bin/env perl
use common::sense;
use Test::More qw(no_plan);
use File::Find qw(finddepth);
use Readonly;
use Getopt::Long;
use Data::Dumper;
use Text::CSV;
use File::Slurp qw(read_file);

Readonly our $METER_CORPUS_DIR          => 't/meter-corpus';
Readonly our $METER_FILE_INDEX_DIR      => "file_index";
Readonly our $METER_NEWSPAPERS_DIR      => "newspapers";
Readonly our $METER_PA_DIR              => "PA";

BEGIN {
    use_ok( 'Text::Plagiarism', qw(
        plagiarizm_prepare
        plagiarizm_prepare_text
        plagiarize_measure
    ) )
        or die "Bail out, main module can't be used!";
}

chdir $METER_CORPUS_DIR;

my %opts = (
    type        => 'raw',
);
GetOptions(
    'help'      => \$opts{help},
    'type=s'    => \$opts{type},
) or help("error while parsing options");

help()      if $opts{help};

given($opts{type}) {
    when(/raw/i) { $opts{type} = 'rawtexts' }
    when(/ann/i) { $opts{type} = 'annotated' }
    default {
        help("invalid type specified: '$opts{type}'");
    }
}

my @derived_files;
run_through_files(
    dirs    => [ $METER_FILE_INDEX_DIR ],
    action  => sub {
        my %a   = (
            file    => undef,
            @_
        );

        return  if $a{file} =~ /readme/i;
        return  unless $a{file} =~ /\.txt$/;
        return  unless $a{file} =~ /(\w_derived)\b/;
        
        push @derived_files, $a{file};
    },
);
my %measure_human;
foreach my $file (@derived_files) {
    $file   =~ /(\w+_derived)/;
    my $measure = $1;

    open( IN, '<', $file )   or die "can't open '$file': $!";
    while(<IN>) {
        chomp;
        s#\s*$##;
        s#meter_corpus/?##;
        $measure_human{$_}  = $measure;
    }
    close IN;
}
#say Dumper('MES',\%measure_human);exit;

my @corpus;
run_through_files(
    dirs    => [ "$METER_PA_DIR/$opts{type}" ],
    action  => sub {
        my %a   = (
            file    => undef,
            @_
        );

        return  if $a{file} =~ /readme/i;
        return  unless $a{file} =~ /\.txt$/;

        push @corpus, {
            file    => $a{file},
        };
    },
);

foreach(@corpus) {
    $_->{text}  = read_file($_->{file});
    $_->{data}  = plagiarizm_prepare(text => $_->{text});
    # TODO check data
    cmp_ok(scalar(keys %{ $_->{data} // {} }), '>', 0, 'check prepared data');
}
say Dumper('CORPUS', \@corpus); exit;

my @articles;
run_through_files(
    dirs    => [ "$METER_NEWSPAPERS_DIR/$opts{type}" ],
    action  => sub {
        my %a   = (
            file    => undef,
            @_
        );

        return  if $a{file} =~ /readme/i;
        return  unless $a{file} =~ /\.txt$/;

        push @articles, {
            file    => $a{file},
        };
    },
);

diag( "#corpus: ".scalar(@corpus)." #articles: ".scalar(@articles) );
foreach my $art (@articles) {
    $art->{text}  = plagiarizm_prepare_text( read_file($art->{file}) );

    if(!exists $measure_human{ $art->{file} }) {
        diag("no such file '$art->{file}' in annotations, skip");
        next;
    }
    else {
        diag("such file '$art->{file}' exists in annotations, checking");
    }
    my $measure_human   = $measure_human{ $art->{file_standard} };

    $art->{data}  = plagiarizm_prepare(text => $_->{text});
    # TODO check data
    cmp_ok(scalar(keys %{ $art->{data} // {} }), '>', 0, 'check prepared data');

    my $max;
    foreach my $c (@corpus) {
        my $plag    = plagiarize_measure(
            text0   => $art->{text},
            data0   => $art->{data},
            text1   => $c->{text},
            data1   => $c->{data},
        );
        ok(defined $plag, "defined plagiarizm measure");
        if(!defined $max || $max < $plag) {
            $max    = $plag;
        }

        #diag( Dumper( 'REUSE', $art->{file_standard}, $measure_human{ $art->{file_standard} } ) );
    }

    if(defined $max) {
        cmp_ok(abs($max - $measure_human), '<=', 0.5, "defined plagiarizm measure");
    }
}

exit;

sub run_through_files {
    my %a   = (
        action  => sub {},
        dirs    => [],
        @_
    );
    finddepth( file_action(%a), @{ $a{dirs} // [] } );
}

sub cwd {
    state $dir;
    unless(defined $dir) {
        if($FindBin::Bin =~ m#\bt/#) {
            $dir    = $FindBin::Bin;
            $dir    =~ s#t/.*#t#;
        }
        else {
            $dir    = '.';
        }
    }
    $dir;
}

sub file_action {
    my %a   = (
        action  => sub {},
        @_
    );
    my $action  = $a{action};

    return sub {
        # $File::Find::dir is the current directory name,
        # $_ is the current filename within that directory
        # $File::Find::name is the complete pathname to the file.
        return if $File::Find::dir =~ /\.(?:svn|git)/;

        my $fname   = $File::Find::name;
        my $dir     = cwd();
        $fname      =~ s#\Q$dir\E/##;

        &$action(
            file    => $fname,
        );
    };
}

sub help {
    say join("\n", @_)."\n";
    say <<HELP;
Usage:
$0 [-h|--help] [--type raw|annotated]

Options:
-h|--help               - print this help message
--type raw|annotated    - which type of articles to use

Description:
Provide tests using meter-corpus

HELP
    exit scalar @_;
}
