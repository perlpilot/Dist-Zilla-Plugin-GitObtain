package Dist::Zilla::Plugin::GitObtain;

# ABSTRACT: obtain files from a git repository before building the distribution

our $VERSION = '0.01';

use Cwd;
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
            $args{$arg} = $repos{$project};
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

sub before_build {
    my $self = shift;

    make_path($self->git_dir) or die "Can't create dir " . $self->git_dir . " -- $!";
    for my $project (keys %{$self->_repos}) {
        my ($url,$tag) = map { $self->_repos->{$project}{$_} } qw/url tag/;
        $self->log("cloning $project ($url)");
        my $git = Git::Wrapper->new($self->git_dir);
        $git->clone($url,$project) or die "Can't clone repository $url -- $!";
        next unless $tag;
        $self->log("checkout $tag");
        my $git_tag = Git::Wrapper->new($self->git_dir . '/' . $project);
        $git_tag->checkout($tag);
    }
}


sub after_build {
    my $self = shift;
    remove_tree($self->git_dir) or die "Can't remove dir " . $self->git_dir . " -- $!";
}


1;
