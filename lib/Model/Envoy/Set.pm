package Model::Envoy::Set;

use MooseX::Role::Parameterized;
use Module::Runtime 'use_module';
use Moose::Util::TypeConstraints;
use MooseX::ClassAttribute;

our $VERSION = '0.1.1';

=head1 Model::Envoy::Set

A role for creating, finding and listing Model::Envoy based objects. Similar in
philosophy to DBIx::Class::ResultSets.

=head2 Required Methods

There is one method you will need to implement in a class that uses this role:

=head3 namespace()

This should return the parent namespace of the Model::Envoy based classes you are 
creating.  For exampe, if you have My::Model::Foo and My::Model::Bar that both use
the Model::Envoy role, then you could define My::Models to use Model::Envoy::Set and it's
namespace method would return 'My::Model'.

=cut

parameter namespace => (
    isa      => 'Str',
    required => 1,
);

role {

    my $namespace = shift->namespace;

    class_has _namespace => (
        isa => 'Str',
        is  => 'rw',
        default => sub { $namespace },
    );
};

has model_class => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);


=head2 Methods

=head3 m($type)

Returns an Envoy::Set of the specified $type. So for a class My::Model::Foo

    my $set = My::Models->m('Foo');

=cut

sub m {
    my ( $class, $name ) = @_;

    my $namespace = $class->_namespace;

    $name =~ s/^$namespace\:://;

    return $class->new( model_class => "$namespace\::$name" );
}

=head3 build(%params)

Create a new instance of the Model::Envoy based class referenced by the set:

    my $instance = $set->build({
        attribute => $value,
        ...
    });

=cut

sub build {
    my( $self, $params, $no_rel ) = @_;

    if ( ! ref $params ) {
        die "Cannot build a ". $self->model_class ." from '$params'";
    }
    elsif( ref $params eq 'HASH' ) {
        return $self->model_class->new(%$params);
    }
    elsif( ref $params eq 'ARRAY' ) {
        die "Cannot build a ". $self->model_class ." from an Array Ref";
    }
    elsif( blessed $params && $params->isa( $self->model_class ) ) {
        return $params;
    }
    elsif( blessed $params && $params->isa( 'DBIx::Class::Core' ) ) {

        my $type = ( ( ref $params ) =~ / ( [^:]+ ) $ /x )[0];

        return $self->m( $type )->model_class->new_from_db($params, $no_rel);
    }
    else {
        die "Cannot coerce a " . ( ref $params ) . " into a " . $self->model_class;
    }
}

=head3 fetch(%params)

Retrieve an object from storage

    my $instance = $set->fetch( id => 1 );

=cut

sub fetch {
    my $self = shift;
    my %params;

    return undef unless @_;

    if ( @_ == 1 ) {

        my ( $id ) = @_;

        $params{id} = $id;
    }
    else {

        my ( $key, $value ) = @_;

        $params{$key} = $value;
    }

    if ( my $result = ($self->model_class->_schema->resultset( $self->model->dbic )
        ->search(\%params))[0] ) {

        return $self->model_class->new_from_db($result);
    }

    return undef;
}

sub _dispatch {
    my ( $self, $method, @params ) = @_;

    while ( my ( $package, $instance ) = each %{$self->_storage} ) {
        warn "dispatch $method to $package";
        if ( ref $instance eq 'HASH' ) {
            $instance = $self->_storage->{$package} = $package->new( %$instance, model => $self );
        }

        $instance->$method();
    }
}


=head3 list(%params)

Query storage and return a list of objects that matched the query

    my $instances = $set->list(
        color => 'green',
        size  => 'small',
        ...
    );

=cut

sub list {
    my $self = shift;

    return [
        map {
            $self->model_class->new_from_db($_);
        }
        $self->model_class->_schema->resultset( $self->model_class->dbic )->search(@_)
    ];
}

=head3 load_types(@names)

For now Model::Envoy does not slurp all the classes in a certain namespace
for use with $set->m().  Call load_types() at the start of your program instead:

    My::Models->load_types( qw( Foo Bar Baz ) );

=cut

sub load_types {
    my ( $self, @types ) = @_;

    my $namespace = $self->_namespace;

    foreach my $type ( @types ) {

        die "invalid type name '$type'" unless $type =~ /^[a-z]+$/i;

        use_module("$namespace\::$type")
            or die "Could not load model type '$type'";
    }
}

1;