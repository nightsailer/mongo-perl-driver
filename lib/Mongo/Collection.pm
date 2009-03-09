package Mongo::Collection;

use Mouse;

has _database => (
    is       => 'ro',
    isa      => 'Mongo::Database',
    required => 1,
    handles  => [qw/query find_one insert update remove ensure_index/],
);

has name => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has full_name => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    builder => '_build_full_name',
);

sub _build_full_name {
    my ($self) = @_;
    my $name    = $self->name;
    my $db_name = $self->_database->name;
    return "${db_name}.${name}";
}

around qw/query find_one insert update remove ensure_index/ => sub {
    my ($next, $self, @args) = @_;
    return $self->$next($self->_query_ns, @args);
};

sub _query_ns {
    my ($self) = @_;
    return $self->name;
}

sub count {
    my ($self, $query) = @_;
    $query ||= {};
    my $obj = $self->_database->run_command({
        count => $self->name,
        query => $query,
    });
    return $obj->{n};
}

sub validate {
    my ($self, $scan_data) = @_;
    $scan_data = 0 unless defined $scan_data;
    my $obj = $self->_database->run_command({ validate => $self->name });
}

sub drop_indexes {
    my ($self) = @_;
    return $self->drop_index('*');
}

sub drop_index {
    my ($self, $index_name) = @_;
    return $self->_database->run_command([
        deleteIndexes => $self->name,
        index         => $index_name,
    ]);
}

sub get_indexes {
    my ($self) = @_;
    return $self->_database->get_collection('system.indexes')->query({
        ns => $self->full_name,
    })->all;
}

sub drop {
    my ($self) = @_;
    $self->drop_indexes;
    $self->_database->run_command({ drop => $self->name });
    return;
}

no Mouse;
__PACKAGE__->meta->make_immutable;

1;
