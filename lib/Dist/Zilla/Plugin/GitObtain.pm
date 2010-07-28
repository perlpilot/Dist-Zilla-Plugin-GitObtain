package Dist::Zilla::Plugin::GitObtain;

# ABSTRACT: obtain files from a git repository before building a distribution

use Git::Wrapper;
use File::Path qw/ make_path remove_tree /;
use Moose;
use namespace::autoclean;

with 'Dist::Zilla::Role::Plugin';
with 'Dist::Zilla::Role::BeforeBuild';
with 'Dist::Zilla::Role::AfterBuild';

has 'git_dir' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
    default => 'src',
);

has 'keep_git_dirs' => (
    is => 'rw',
    isa => 'Bool',
    required => 1,
    default => 0,
);

has _repos => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { {} },
);

sub BUILDARGS {
    my $class = shift;
    my %repos = ref($_[0]) ? %{$_[0]} : @_;

    my $zilla = delete $repos{zilla};
    my $name = delete $repos{plugin_name};

    my %args;
    for my $project (keys %repos) {
        if ($project =~ /^--/) {
            (my $arg = $project) =~ s/^--//;
            $args{$arg} = delete $repos{$project};
            next;
        }
        my ($url,$tag) = split ' ', $repos{$project};
        $repos{$project} = { url => $url, tag => $tag };
    }

    return {
        zilla => $zilla,
        plugin_name => $name,
        _repos => \%repos,
        %args,
    };
}

my $git_dir_exists = 0;

sub before_build {
    my $self = shift;

    if (-d $self->git_dir) {
        $git_dir_exists = 1;
        $self->log("using existing directory " . $self->git_dir);
    } else {
        $self->log("creating directory " . $self->git_dir);
        make_path($self->git_dir) or die "Can't create directory " . $self->git_dir . " -- $!";
    }
    for my $project (keys %{$self->_repos}) {
        my ($url,$tag) = map { $self->_repos->{$project}{$_} } qw/url tag/;
        $self->log("cloning $project");
        my $git = Git::Wrapper->new($self->git_dir);
        $git->clone($url,$project) or die "Can't clone repository $url -- $!";
        next unless $tag;
        $self->log("checkout $project revision $tag");
        my $git_tag = Git::Wrapper->new($self->git_dir . '/' . $project);
        $git_tag->checkout($tag);
    }
}


sub _remove_dir {
    my ($self,$dir) = @_;
    $self->log("removing $dir");
    remove_tree($dir) or warn "Can't remove directory $dir -- $!\n";
}

sub after_build {
    my $self = shift;
    return if $self->keep_git_dirs;
    if ($git_dir_exists) {
        for my $project (keys %{$self->_repos}) {
            my $dir = $self->git_dir . '/' . $project;
            $self->_remove_dir($dir);
        }
    } else {
        $self->_remove_dir($self->git_dir);
    }
}

__PACKAGE__->meta->make_immutable;
1;

__END__
=pod

=head1 NAME

Dist::Zilla::Plugin::GitObtain - obtain files from a git repository before building a distribution

=head1 SYNOPSIS

In your F<dist.ini>:

  [GitObtain]
    --git_dir       = some_dir
    --keep_git_dirs = 1
    ;package    = url                                           tag
    rakudo      = git://github.com/rakudo/rakudo.git            2010.06
    http-daemon = git://gitorious.org/http-daemon/mainline.git

=head1 DESCRIPTION

This module uses L<Git::Wrapper> to obtain files from git repositories
before building a distribution.

You may specify the directory the git repositories will be placed into
by using the C<--git_dir> option.  This directory path will be created
if it does not already exist (including intermediate directories).
After the build is complete, this directory will be removed.  If you do
not specify C<--git_dir>, a default value of "src" will be used.
If you don't want the directories that are created to be removed after
the completion of the build, set C<--keep_git_dirs> to be a true value.

Each repository has a name that will be used as the directory within the
C<--git_dir> directory to place a clone of the git repository specified
by the URL.  Optionally, each URL may be followed by a "tag" name that
will be checked out of the git repository.  (Anything that may be passed
to C<git checkout> may be used for the "tag".)

=head1 AUTHOR

Jonathan Scott Duff <duff@pobox.com>

=head1 COPYRIGHT

This software is copyright (c) 2010 by Jonathan Scott Duff

This is free sofware; you can redistribute it and/or modify it under the
same terms as the Perl 5 programming language itself.

=cut
