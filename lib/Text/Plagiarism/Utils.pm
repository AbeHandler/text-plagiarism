package Text::Plagiarism::Utils;
use common::sense;
use Exporter::Easy (
    EXPORT  => [qw(
        module2path
        module_base_dir
    )],
);

sub module2path {
    my $m   = shift // __PACKAGE__;
    $m      =~ s#::#/#g;
    "$m.pm";
}

sub module_base_dir {
    my $module  = shift // __PACKAGE__;
    my $path    = module2path($module);
    $path       = $INC{$path};
    $path       =~ s#/?\Q$path\E$##;
    $path       =~ s#/?lib/?$##;
    $path       = $ENV{PWD}     unless length $path;
    $path       = '.'           unless length $path;
    $path;
}

8;
