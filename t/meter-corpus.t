#!/usr/bin/env perl
use common::sense;
use Test::More qw(no_plan);
use File::Find qw(finddepth);
use Readonly;
use Getopt::Long;
use Data::Dumper;
use Text::CSV;
use File::Slurp qw(read_file);
use Time::HiRes qw(time);

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
    type            => 'raw',
    ngram           => 2,
    no_prepare      => 1,
    print_failed    => 0,
);
GetOptions(
    'help'          => \$opts{help},
    'type=s'        => \$opts{type},
    'ngram=i'       => \$opts{ngram},
    'no-prepare'    => \$opts{no_prepare},
    'print-failed'  => \$opts{print_failed},
) or help("error while parsing options");

help()      if $opts{help};

given($opts{type}) {
    when(/raw/i) { $opts{type} = 'rawtexts' }
    when(/ann/i) { $opts{type} = 'annotated' }
    default {
        help("invalid type specified: '$opts{type}'");
    }
}

diag("loading derived files");
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

diag("loading human measures for derived files");
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

diag("loading PA corpus");
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

diag("prepare PA corpus");
my %corpus_by_event;
my $progress    = 0;
my $start       = time;
foreach(@corpus) {
    $progress++;
    progress(
        progress    => $progress,
        overall     => scalar( @corpus ),
        start       => $start,
    );

    $_->{text}  = read_file($_->{file});
    unless($opts{no_prepare}) {
        $_->{data}  = plagiarism_prepare_custom(
            text                => $_->{text},
            sentences           => 0,
            shingles_prepare    => 1,
            ngram               => $opts{ngram},
        );
    }

    my $event   = file2event($_->{file});
    push @{ $corpus_by_event{ $event } }, $_;
}
#diag( Dumper('CORPUS', \@corpus) );
#diag( Dumper('CORPUS by event', \%corpus_by_event) );
diag( "corpus size - ".scalar(@corpus).", number of events in corpus - ".scalar(keys %corpus_by_event) );

diag("loading newspapers files");
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

my @results;
my $learn_part  = 0.8;
my $idx         = 0;
my @articles_learn  = grep {
        $idx++ <= $learn_part*scalar(@articles) ? ($_) : ()
    }
    @articles;
my $idx         = 0;
my @articles_test   = grep {
        $idx++ > $learn_part*scalar(@articles) ? ($_) : ()
    }
    @articles;

diag("learn cycle");
my $progress    = 0;
my $start       = time;
foreach my $art (@articles_learn) {
    $progress++;
    progress(
        progress    => $progress,
        overall     => scalar( @articles_learn ),
        start       => $start,
    );

    $art->{text}  = scalar read_file($art->{file});

    if(!exists $measure_human{ $art->{file} }) {
        #diag("no such file '$art->{file}' in annotations, skip");
        next;
    }
    else {
        #diag("such file '$art->{file}' exists in annotations, checking");
    }
    my $measure_human   = $measure_human{ $art->{file} };

    unless($opts{no_prepare}) {
        $art->{data}  = plagiarism_prepare_custom(
            text        => $art->{text},
            sentences   => 1,
            ngram       => $opts{ngram},
        );
    }
    #cmp_ok(scalar(keys %{ $art->{data} // {} }), '>', 0, 'check prepared data');

    my $event   = file2event($art->{file});
    #say Dumper($event, $corpus_by_event{$event});

    my ($max, $max_on_file);
    foreach my $c (@{ $corpus_by_event{$event} }) {
        my $plag    = plagiarism_measure_custom(
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

    #diag("max plagiarism measure - '$max', human - '$measure_human', reached on file - '$max_on_file'");
    if(defined $max) {
        #cmp_ok(abs($max - $measure_human), '<=', 0.25, "plagiarism measure '$max' VS '$measure_human' - human one");

        push @results, {
            human   => $measure_human,
            machine => $max,
        };
    }
}

diag("calculate best parameters");
# run through whole space and find best parameters for:
# 0 <= a <= b <= 1
# which will divide space in 3 types:
# * non derived
# * partially derived
# * wholly derived
my @results_sorted      = sort {$a->{machine} <=> $b->{machine}} @results;
my @results_sorted_rev  = reverse @results_sorted;
my ($a_best, $b_best, $record_a, $record_b);
for(my $i=0; $i<(@results_sorted-1); $i++) {
    my $r       = $results_sorted[$i];
    my $r2      = $results_sorted[$i+1];
    my $a_cur   = ($r->{machine} + $r2->{machine}) / 2;
    my $record_a_cur = 0;

    my $r_rev   = $results_sorted_rev[$i];
    my $r2_rev  = $results_sorted_rev[$i+1];
    my $b_cur   = ($r_rev->{machine} + $r2_rev->{machine}) / 2;
    my $record_b_cur = 0;

    foreach my $r (@results) {
        if(0 == $r->{human}) {
            if($r->{machine} < $a_cur) {
                $record_a_cur++;
            }
        }
        else {
            if($a_cur < $r->{machine}) {
                $record_a_cur++;
            }
        }

        if(1 == $r->{human}) {
            if($b_cur < $r->{machine}) {
                $record_b_cur++;
            }
        }
        else {
            if($r->{machine} < $b_cur) {
                $record_b_cur++;
            }
        }
    }

    if(!defined($record_a) || $record_a < $record_a_cur) {
        $record_a   = $record_a_cur;
        $a_best     = $a_cur;
    } 

    if(!defined($record_b) || $record_b < $record_b_cur) {
        $record_b   = $record_b_cur;
        $b_best     = $b_cur;
    } 
}

my $record  = 0;
foreach(@results) {
    my $machine = $_->{machine};
    if($_->{machine} <= $a_best) {
        $machine    = 0;
    }
    elsif($_->{machine} <= $b_best) {
        $machine    = 0.5;
    }
    else {
        $machine    = 1;
    }

    if($machine == $_->{human}) {
        $record++;
    }
}
my $n   = scalar @results;
diag("a best - $a_best, record - $record_a, all - $n, ".int(100*$record_a/$n)."\%");
diag("b best - $b_best, record - $record_b, all - $n, ".int(100*$record_b/$n)."\%");
diag("  overall record - $record, all - $n, ".int(100*$record/$n)."\%");
#say Dumper(\@results_sorted);

diag("test cycle");
my (@failed, @failed_01);
$start      = time;
$progress   = 0;
foreach my $art (@articles_test) {
    $progress++;
    progress(
        progress    => $progress,
        overall     => scalar( @articles_test ),
        start       => $start,
    );

    $art->{text}  = scalar read_file($art->{file});

    if(!exists $measure_human{ $art->{file} }) {
        #diag("no such file '$art->{file}' in annotations, skip");
        next;
    }
    else {
        #diag("such file '$art->{file}' exists in annotations, checking");
    }
    my $measure_human   = $measure_human{ $art->{file} };

    unless($opts{no_prepare}) {
        $art->{data}  = plagiarism_prepare_custom(
            text        => $art->{text},
            sentences   => 1,
            ngram       => $opts{ngram},
        );
    }
    #cmp_ok(scalar(keys %{ $art->{data} // {} }), '>', 0, 'check prepared data');

    my $event   = file2event($art->{file});
    #say Dumper($event, $corpus_by_event{$event});

    my ($max, $max_on_file, $max_file);
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
            $max_file       = $c;
        }

        #diag( "measure our '$plag' VS '$measure_human', file: $art->{file}" );
    }

    my $max2    = $max;
    my $max2_01 = $max;
    if($max <= $a_best) {
        $max2   = 0;
        $max2_01= 0;
    }
    elsif($max <= $b_best) {
        $max2   = 0.5;
        $max2_01= 1;
    }
    else {
        $max2   = 1;
        $max2_01= 1;
    }

    $art->{max_on_file} = $max_on_file;
    $art->{max_file}    = $max_file;
    $art->{max}         = $max;
    $art->{max2}        = $max2;
    $art->{max2_01}     = $max2_01;
    $art->{a_best}      = $a_best;
    $art->{b_best}      = $b_best;

    #diag("max plagiarism measure - '$max', identified as - '$max2', human - '$measure_human', reached on file - '$max_on_file'");
    if(defined $max) {

        #is($max2, $measure_human, "plagiarism measure '$max2' VS '$measure_human' - human one");

        push @failed, [
            query_text                  => $art->{data}->{text},
            query_words                 => $art->{data}->{words},
            max_on_file                 => $art->{max_on_file},
            document_words              => $art->{max_file}->{data}->{words},
            document_text               => $art->{max_file}->{text},
            measure                     => $max,
            measure2                    => $max2,
            human                       => $measure_human,
        ]
            unless $max2 == $measure_human;

        my $measure_human_01    = 0 < $measure_human ? 1 : 0;
        push @failed_01, [
            query_text                  => $art->{data}->{text},
            query_words                 => $art->{data}->{words},
            max_on_file                 => $art->{max_on_file},
            document_words              => $art->{max_file}->{data}->{words},
            document_text               => $art->{max_file}->{text},
            measure                     => $max,
            measure2_01                 => $max2_01,
            human_01                    => $measure_human_01,
        ]
            unless $max2_01 == $measure_human_01;
    }
}

my $n2          = scalar @articles_test;
my $n_failed    = scalar @failed;
my $n_failed_01 = scalar @failed_01;
my $n_succeed   = $n2 - $n_failed;
my $n_succeed_01= $n2 - $n_failed_01;
diag("  succeed - $n_succeed, all - $n2, ".int(100*$n_succeed/$n2)."\%");
diag("  succeed 01 - $n_succeed_01, all - $n2, ".int(100*$n_succeed_01/$n2)."\%");

say Dumper(\@failed)    if $opts{print_failed};

# later:
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
$0 [-h|--help] [--type raw|annotated] [--ngram N]

Options:
-h|--help               - print this help message
--type raw|annotated    - which type of articles to use
--ngram N               - what N to ues for n-grams (aka shingles), more on topic:
                          https://en.wikipedia.org/wiki/N-gram
                          https://en.wikipedia.org/wiki/W-shingling

Description:
Provide tests using meter-corpus

HELP
    exit scalar @_;
}

sub plagiarism_measure_custom {
    my %a   = (@_);
    plagiarism_measure(
        %a,
        ngram                               => $opts{ngram},
        #use_synsets                         => 1,
        #min_sentence_length                 => 1,
        # can be a string with function name or a callback
        #result_sentence_measure_function    => 'result_sentence_measure_avg',
        #result_sentence_measure_function    => 'result_sentence_measure_max_avg',
    );
}

sub plagiarism_prepare_custom {
    my %a   = (@_);
    plagiarism_prepare(
        %a,
        use_dictionary                      => 1,
        use_synsets                         => 0,
        use_seldom_words                    => 0,
    );
}

sub progress {
    my %a   = (
        start       => undef,
        progress    => undef,
        overall     => undef,
        per         => 10,
        @_
    );
    my $progress    = $a{progress};
    my $start       = $a{start};
    my $overall     = $a{overall};
    if(0 == $progress % $a{per}) {
        my $time    = time;
        my $time_est= $overall*($time-$start)/$progress;
        diag(sprintf "%03d / %03d = %02d%% estimated time: %d, time to finish: %d",
            $progress,
            $overall,
            int(100*$progress/$overall),
            $time_est,
            $time_est - ($time - $start),
        );
    }
}
