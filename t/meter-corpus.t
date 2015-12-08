#!/usr/bin/env perl
use common::sense;
use Test::More qw(no_plan);
use File::Find qw(finddepth);
use Readonly;
use Getopt::Long;
use Data::Dumper;
use Text::CSV;

Readonly our $METER_CORPUS_DIR          => 't/meter-corpus';
Readonly our $METER_REUSE_FILE          => "text-reuse-annotations/meter-corpus.csv";
Readonly our $METER_NEWSPAPERS_DIR      => "newspapers";
Readonly our $METER_PA_DIR              => "PA";

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

chdir $METER_CORPUS_DIR;

my @corpus;
run_through_files(
    dirs    => [ $METER_PA_DIR ],
    action  => sub {
        my %a   = (
            file    => undef,
            @_
        );
        push @corpus, $a{file};
    },
);
say Dumper('CORPUS', \@corpus);

# run_through_files(
#     dirs    => [ $METER_NEWSPAPERS_DIR ],
#     action  => sub {
#         say Dumper(\@_);
#     },
# );

# my $data    = reuse_data();
# diag Dumper($data);

exit;

sub reuse_data {
    open( my $IN, '<', $METER_REUSE_FILE)    || help("can't open reuse file - '$METER_REUSE_FILE': $!");
    my $csv = Text::CSV->new({
        sep_char    => "\t",
        binary      => 1,
    });
    my $headers = <$IN>;
    chomp $headers;
    $csv->parse($headers)   || help("can't parse headers '$headers' for reuse file: $!");
    my @headers = $csv->fields();
    my @r;
    foreach(<$IN>) {
        chomp;
        $csv->parse($_)  || help("can't parse line - '$_' for reuse file: $!");
        my @cols    = $csv->fields();
        my %cols;
        @cols{@headers}  = @cols;
        push @r, \%cols;
    }
    \@r;
}

sub run_through_files {
    my %a   = (
        action  => sub {},
        dirs    => [],
        @_
    );
    finddepth( file_action(%a), map {"$_/$opts{type}"} @{ $a{dirs} // [] });
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
        return if /readme/i;
        return unless /\.txt$/;

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
