#!/usr/bin/env perl
use common::sense;
use Test::More qw(no_plan);
use File::Find qw(finddepth);
use Readonly;
use Getopt::Long;
use Data::Dumper;
use Text::CSV;
use File::Slurp qw(read_file);

$|  = 1;

Readonly our $METER_CORPUS_DIR          => 't/meter-corpus';
Readonly our $METER_FILE_INDEX_DIR      => "file_index";
Readonly our $METER_NEWSPAPERS_DIR      => "newspapers";
Readonly our $METER_PA_DIR              => "PA";

BEGIN {
    use_ok( 'Text::Plagiarism', qw(
        plagiarism_prepare
        plagiarism_prepare_text
        plagiarism_measure
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
    $file   =~ /(\w+)_derived/;
    my $measure = $1;
    given($measure) {
        when(/non/i) {          $measure = 0 }
        when(/partiall?y/i) {   $measure = .5 }
        when(/whol/i) {         $measure = 1 }
        default {
            die "unknown human measure: '$_'";
        }
    }

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

my %corpus_by_event;
foreach(@corpus) {
    $_->{text}  = read_file($_->{file});
    $_->{data}  = plagiarism_prepare(text => $_->{text});
    #cmp_ok(scalar(keys %{ $_->{data} // {} }), '>', 0, 'check prepared data');

    my $event   = file2event($_->{file});
    push @{ $corpus_by_event{ $event } }, $_;
}
#diag( Dumper('CORPUS', \@corpus) );
#diag( Dumper('CORPUS by event', \%corpus_by_event) );
diag( "corpus size - ".scalar(@corpus).", number of events in corpus - ".scalar(keys %corpus_by_event) );

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
diag( "number of articles - ".scalar(@articles) );

foreach my $art (@articles) {
    $art->{text}  = scalar read_file($art->{file});

    if(!exists $measure_human{ $art->{file} }) {
        diag("no such file '$art->{file}' in annotations, skip");
        next;
    }
    else {
        diag("such file '$art->{file}' exists in annotations, checking");
    }
    my $measure_human   = $measure_human{ $art->{file} };

    $art->{data}  = plagiarism_prepare(
        text        => $_->{text},
        sentences   => 1,
        ngram       => 2,
    );
    #cmp_ok(scalar(keys %{ $art->{data} // {} }), '>', 0, 'check prepared data');

    my $event   = file2event($art->{file});
    #say Dumper($event, $corpus_by_event{$event});

    my ($max, $max_on_file);
    foreach my $c (@{ $corpus_by_event{$event} }) {
        my $plag    = plagiarism_measure(
            query_text      => $art->{text},
            query_data      => $art->{data},
            document_text   => $c->{text},
            document_data   => $c->{data},
        );
        if(!defined $max || $max < $plag) {
            $max            = $plag;
            $max_on_file    = $c->{file};
        }

        #diag( "measure our '$plag' VS '$measure_human', file: $art->{file}" );
    }

    diag("max plagiarism measure - '$max', human - '$measure_human', reached on file - '$max_on_file'");
    if(defined $max) {
        cmp_ok(abs($max - $measure_human), '<=', 0.25, "plagiarism measure '$max' VS '$measure_human' - human one");
    }
}

# TODO run through whole space and find best parameters for:
# 0 <= a <= b <= 1
# which will divide space in 3 types:
# * non derived
# * partially derived
# * wholly derived
#
# 2nd stage: run it on part of the space
# 3rd stage: think how to do it quicker

exit;

sub file2event {
    my $event   = shift;
    $event      =~ s#\Q$METER_PA_DIR\E/##;
    $event      =~ s#\Q$METER_NEWSPAPERS_DIR\E/##;
    $event      =~ s#(.*)/.*$#$1#;
    $event;
}

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
