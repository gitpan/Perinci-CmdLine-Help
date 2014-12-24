package Perinci::CmdLine::Help;

our $DATE = '2014-12-23'; # DATE
our $VERSION = '0.01'; # VERSION

use 5.010001;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(gen_help);

our %SPEC;

$SPEC{gen_help} = {
    v => 1.1,
    summary => 'Generate help message for Perinci::CmdLine-based app',
    args => {
        program_name => {
            schema => 'str*',
            req => 1,
        },
        program_summary => {
            schema => 'str*',
        },
        meta => {
            summary => 'Function metadata, must be normalized',
            schema => 'hash*',
            req => 1,
        },
        common_opts => {
            schema => 'hash*',
            default => {},
        },
        per_arg_json => {
            schema => 'bool*',
        },
        per_arg_yaml => {
            schema => 'bool*',
        },
    },
};
sub gen_help {
    my %args = @_;

    my $meta = $args{meta};
    my $common_opts = $args{common_opts} // {};

    my @help;

    # summary
    my $progname = $args{program_name};
    push @help, $progname;
    {
        my $sum = $args{program_summary} // $meta->{summary};
        last unless $sum;
        push @help, " - ", $sum, "\n";
    }

    my $clidocdata;

    # usage
    push @help, "\n";
    push @help, "Usage:\n";
    {
        for (sort {
            ($common_opts->{$a}{order} // 99) <=>
                ($common_opts->{$b}{order} // 99) ||
                    $a cmp $b
            } keys %$common_opts) {
            my $co = $common_opts->{$_};
            next unless $co->{usage};
            push @help, "  $progname $co->{usage}\n";
        }

        require Perinci::Sub::To::CLIDocData;
        my $res = Perinci::Sub::To::CLIDocData::gen_cli_doc_data_from_meta(
            meta => $meta, meta_is_normalized => 1,
            common_opts  => $common_opts,
            per_arg_json => $args{per_arg_json},
            per_arg_yaml => $args{per_arg_yaml},
        );
        die [500, "gen_cli_doc_data_from_meta failed: ".
                 "$res->[0] - $res->[1]"] unless $res->[0] == 200;
        $clidocdata = $res->[2];
        my $usage = $clidocdata->{usage_line};
        $usage =~ s/\[\[prog\]\]/$progname/;
        push @help, "  $usage\n";
    }

    # example
    {
        last unless @{ $clidocdata->{examples} };
        push @help, "\n";
        push @help, "Examples:\n";
        my $i = 0;
        my $egs = $clidocdata->{examples};
        for my $eg (@$egs) {
            $i++;
            my $cmdline = $eg->{cmdline};
            $cmdline =~ s/\[\[prog\]\]/$progname/;
            push @help, "  $eg->{summary}:\n" if $eg->{summary};
            push @help, "  % $cmdline\n";
            push @help, "\n" if $eg->{summary} && $i < @$egs;
        }
    }

    # description
    {
        my $desc = $args{program_description} // $meta->{description};
        last unless $desc;
        push @help, "\n";
        $desc =~ s/\A\n+//;
        $desc =~ s/\n+\z//;
        push @help, $desc, "\n";
    }

    # options
    {
        require Data::Dmp;

        my $opts = $clidocdata->{opts};
        last unless keys %$opts;

        # find all the categories
        my %cats; # val=[options...]
        for (keys %$opts) {
            push @{ $cats{$opts->{$_}{category}} }, $_;
        }

        for my $cat (sort keys %cats) {
            # find the longest option
            my @opts = sort {length($b)<=>length($a)} @{ $cats{$cat} };
            my $len = length($opts[0]);
            # sort again by name
            @opts = sort {
                (my $a_without_dash = $a) =~ s/^-+//;
                (my $b_without_dash = $b) =~ s/^-+//;
                lc($a) cmp lc($b);
            } @opts;
            push @help, "\n$cat:\n";
            for my $opt (@opts) {
                my $ospec = $opts->{$opt};
                my $arg_spec = $ospec->{arg_spec};
                my $is_bool = $arg_spec->{schema} &&
                    $arg_spec->{schema}[0] eq 'bool';
                my $show_default = exists($ospec->{default}) &&
                    !$is_bool && !$ospec->{is_base64} &&
                        !$ospec->{is_json} && !$ospec->{is_yaml} &&
                            !$ospec->{is_alias};

                my $add_sum = '';
                if ($ospec->{is_base64}) {
                    $add_sum = " (base64-encoded)";
                } elsif ($ospec->{is_json}) {
                    $add_sum = " (JSON-encoded)";
                } elsif ($ospec->{is_yaml}) {
                    $add_sum = " (YAML-encoded)";
                }

                my $argv = '';
                if (!$ospec->{main_opt} && defined($ospec->{pos})) {
                    if ($ospec->{greedy}) {
                        $argv = " (=arg[$ospec->{pos}-])";
                    } else {
                        $argv = " (=arg[$ospec->{pos}])";
                    }
                }

                my $cmdline_src = '';
                if (!$ospec->{main_opt} && defined($arg_spec->{cmdline_src})) {
                    $cmdline_src = " (or from $arg_spec->{cmdline_src})";
                    $cmdline_src =~ s!_or_!/!g;
                }

                push @help, sprintf(
                    "  %-${len}s  %s%s%s%s%s\n",
                    $opt,
                    $ospec->{summary}//'',
                    $add_sum,
                    $argv,
                    $cmdline_src,
                    ($show_default ?
                         " [".Data::Dmp::dmp($ospec->{default})."]":""),

                );
            }
        }
    }

    [200, "OK", join("", @help)];
}

1;
# ABSTRACT: Generate help message for Perinci::CmdLine-based app

__END__

=pod

=encoding UTF-8

=head1 NAME

Perinci::CmdLine::Help - Generate help message for Perinci::CmdLine-based app

=head1 VERSION

This document describes version 0.01 of Perinci::CmdLine::Help (from Perl distribution Perinci-CmdLine-Help), released on 2014-12-23.

=head1 DESCRIPTION

Currently used by L<Perinci::CmdLine::Lite> and L<App::riap>. Eventually I want
L<Perinci::CmdLine> to use this also (needs prettier and more sophisticated
formatting options first though).

=head1 FUNCTIONS


=head2 gen_help(%args) -> [status, msg, result, meta]

Generate help message for Perinci::CmdLine-based app.

Arguments ('*' denotes required arguments):

=over 4

=item * B<common_opts> => I<hash> (default: {})

=item * B<meta>* => I<hash>

Function metadata, must be normalized.

=item * B<per_arg_json> => I<bool>

=item * B<per_arg_yaml> => I<bool>

=item * B<program_name>* => I<str>

=item * B<program_summary> => I<str>

=back

Return value:

Returns an enveloped result (an array).

First element (status) is an integer containing HTTP status code
(200 means OK, 4xx caller error, 5xx function error). Second element
(msg) is a string containing error message, or 'OK' if status is
200. Third element (result) is optional, the actual result. Fourth
element (meta) is called result metadata and is optional, a hash
that contains extra information.

 (any)

=for Pod::Coverage ^()$

=head1 SEE ALSO

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Perinci-CmdLine-Help>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Perinci-CmdLine-Help>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Perinci-CmdLine-Help>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
