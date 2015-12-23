package Text::Plagiarism::SynSet::Config;
use common::sense;
use Text::Plagiarism::Utils qw(module_base_dir);
use Readonly;
use Exporter::Easy (
    EXPORT  => [qw(
        synset_load
        synset_save
        synset_append
        synset_file
        synset_open
    )],
);

Readonly our $SYNSET_FILE   => 'dictionary/synset.txt';

sub synset_file {
    module_base_dir() . "/$SYNSET_FILE";
}

sub synset_load {
    my %a   = (
        file_name   => undef,
        file_handle => undef,
        @_
    );

    unless($a{file_handle}) {
        $a{file_handle} = synset_open(
            file_name   => $a{file_name},
            mode        => '<',
        );
    }

    my (%synsets, $synset_id, @terms);
    my $fh  = $a{file_handle};
    while(<$fh>) {
        chomp;
        if(/^\t(.+)/) {
            push @terms, $1;
        }
        else {
            if($synset_id) {
                $synsets{$synset_id}    = [@terms];
                $synset_id  = undef;
                @terms      = ();
            }
            $synset_id  = $_;
        }
    }

    \%synsets;
}

sub synset_append {
    my %a   = (
        file_handle => undef,
        synset_id   => undef,
        terms       => [],
        @_
    );

    my $fh  = $a{file_handle};
    print $fh "$a{synset_id}\n";

    foreach(@{ $a{terms} // [] }) {
        print $fh "\t$_\n";
    }
}

sub synset_save {
    my %a   = (
        file_name   => undef,
        file_handle => undef,
        synsets     => {},
        @_
    );

    unless($a{file_handle}) {
        $a{file_handle} = synset_open(
            file_name   => $a{file_name},
            mode        => '>',
        );
    }

    while(my ($synset_id, $terms) = each %{ $a{synsets} // {} }) {
        synset_append(
            file_handle => $a{file_handle},
            synset_id   => $synset_id,
            terms       => $terms,
        );
    }
}

sub synset_open {
    my %a   = (
        file_name   => undef,
        mode        => '<',
        @_
    );

    $a{file_name}   //= synset_file();

    my $fh;
    open($fh, $a{mode}, $a{file_name})
        or die "can't open '$a{file_name}' for mode '$a{mode}': $!";
    $fh;
}

8;
