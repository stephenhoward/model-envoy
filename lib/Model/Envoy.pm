package Model::Envoy;

use MooseX::Role::Parameterized;
use Module::Runtime 'use_module';
use List::AllUtils 'first_result';

our $VERSION = '0.3.0';

=head1 Model::Envoy

A Moose Role that can be used to build a model layer which keeps business logic separate from your storage layer.

=head2 Synopsis

    package My::Model::Widget;

        use Moose;
        with 'Model::Envoy' => { storage => {
            'DBIC' => {
                schema => sub {
                    My::DB->db_connect(...);
                }
            },
        };

        sub dbic { 'My::DB::Result::Widget' }


        has 'id' => (
            is => 'ro',
            isa => 'Num',
            traits => ['DBIC'],
            primary_key => 1,

        );

        has 'name' => (
            is => 'rw',
            isa => 'Maybe[Str]',
            traits => ['DBIC'],
        );

        has 'no_storage' => (
            is => 'rw',
            isa => 'Maybe[Str]',
        );

        has 'parts' => (
            is => 'rw',
            isa => 'ArrayRef[My::Model::Part]',
            traits => ['DBIC','Envoy'],
            rel => 'has_many',
        );

    package My::Models;

    use Moose;
    with 'Model::Envoy::Set' => { namespace => 'My::Envoy' };


    ....then later...

    my $widget = My::Models->m('Widget')->build({
        id => 1
        name => 'foo',
        no_storage => 'bar',
        parts => [
            {
                id => 2,
                name => 'baz',
            },
        ],
    });

    $widget->name('renamed');
    $widget->save;

Mixing database logic with business rules is a common hazard when building an application's model layer. Beyond
the violation of the ideal separation of concerns, it also ties a developer's hands when needing to transition
between different storage mechanisms, or support more than one.

Model::Envoy provides an Moose-based object layer to manage business logic, and a plugin system to add one or more
persistence methods under the hood.

=head2 Setting up storage

Indicating which storage back ends you are using for your models is done when you include the role. It makes the most sense to
do this in a base class which your models can inherit from:

    package My::Model;

        use Moose;
        use My::DB;

        my $schema;

        with 'Model::Envoy' => { storage => {
            'DBIC' => {
                schema => sub {
                    $schema ||= My::DB->db_connect(...);
                }
            },
            ...
        } };
    
    # then....

    package My::Model::Widget;

    use Moose;

    extends 'My::Model'

    ...

=head2 Model attributes

Model::Envoy classes use normal Moose attribute declarations. Depending on the storage layer plugin, they may add attribute traits or other methods
your models need to implement to indicate how each attribute finds its way into and out of storage.

=head3 Attribute Type Coercion with the 'Envoy' trait

This trait is handy for class attributes that represent other Model::Envoy
enabled classes (or arrays of them).  It will allow you to pass in hashrefs
(or arrays of hashrefs) to those attributes and have them automagically elevated
into an instance of the intended class.

    has 'parts' => (
        is => 'rw',
        isa => 'ArrayRef[My::Model::Part]',
        traits => ['Envoy'],
    );

=head2 Class Methods

=head3 build()

C<build> is a more flexible version of C<new>.  It can take a standard hashref of properties just as C<new> would, but it can also take
classes that are used by your storage layer plugins and, if those plugins support this, convert them into an instance of your model object.

=head3 get_storage($storage_package)

Passes back the storage plugin specified by C<$storage_package> being used by the class. Follows the same namespace resolution
process as the instance method below.

=head2 Instance Methods

=head3 save()

Save the instance to your persistent storage layer.

=head3 update($hashref)

Given a supplied hashref of attributes, bulk update the attributes of your instance object.

=head3 delete()

Remove the instance from your persistent storage layer.

=head3 dump()

Provide an unblessed copy of the datastructure of your instance object.

=head3 get_storage('Plugin')

Given the namespace of a storage plugin, return the instance of it that's backing the current object.  If the plugin is in the
C<Model::Envoy::Storage::> namespace, it can be abbreviated:

    $model->get_storage('DBIC')  # looks for Model::Envoy::Storage::DBIC

otherwise, prefix your plugin name with a C<+> to get something outside of the default namespace:

    $model->get_storage('+My::Storage::WhatsIt');

=head2 Aggregate methods

For operations that fetch and search for one or more models, see C<Model::Envoy::Set>.

=cut

parameter storage => (
    isa      => 'HashRef',
    required => 1,
);

my $abs_module_prefix = qr/^\+/;

role {

    my $storage = shift->storage;
    my %plugins;

    while ( my ( $package, $conf ) = each %$storage ) {

        my $role = _resolve_namespace($package);

        use_module( $role );

        $plugins{$role} = $conf;
    }

    has _storage => (
        isa => 'HashRef',
        is  => 'ro',
        default => sub {

            my $self = shift;

            return { map { $_ => undef } keys %plugins }
        },
    );

    method 'storage_plugins' => sub {

        \%plugins;
    };
};

sub _resolve_namespace {
    my ( $namespace ) = @_;

    $namespace =~ s/^Model::Envoy::Storage:://;

    return $namespace =~ $abs_module_prefix
        ? do { $namespace =~ s/$abs_module_prefix//; $namespace }
        : 'Model::Envoy::Storage::' . $namespace;
}

sub get_storage {
    my ( $self, $package ) = @_;

    if ( ! ref $self ) {
        return $self->_get_configured_storage_class($package);
    }
    else {
        return $self->_storage_instance($package);
    }
}

sub build {
    my( $class, $params, $no_rel ) = @_;

    if ( ! ref $params ) {

        return undef unless defined $params;

        die "Cannot build a ". $class ." from '$params'";
    }
    elsif( ref $params eq 'HASH' ) {
        return $class->new(%$params);
    }
    elsif( ref $params eq 'ARRAY' ) {
        die "Cannot build a ". $class ." from an Array Ref";
    }
    elsif( blessed $params && $params->isa( $class ) ) {
        return $params;
    }
    elsif( my $model = $class->_dispatch('build', $params, $no_rel ) ) {
        return $model;
    }
    else {
        die "Cannot coerce a " . ( ref $params ) . " into a " . $class;
    }
}

sub save {
    my $self = shift;

    $self->_dispatch('save', @_ );

    return $self;
}

sub update {
    my ( $self, $hashref ) = @_;

    foreach my $attr ( grep { $_->get_write_method } $self->_get_all_attributes ) {

        my $name = $attr->name;

        if ( exists $hashref->{$name} ) {

            $self->$name( $hashref->{$name} );
        }
    }

    return $self;
}


sub delete {
    my ( $self ) = @_;

    $self->_dispatch('delete', @_ );

    return 1;
}

sub dump {
    my ( $self ) = @_;

    return {
        map  { $_ => $self->_dump_property( $self->$_ ) }
        grep { defined $self->$_ }
        map  { $_->name }
        $self->_get_all_attributes
    };
}


sub _dump_property {
    my ( $self, $value ) = @_;

    return $value if ! ref $value;

    return [ map { $self->_dump_property($_) } @$value ] if ref $value eq 'ARRAY';

    return { map { $_ => $self->_dump_property( $value->{$_} ) } keys %$value } if ref $value eq 'HASH';

    return $value->dump if $value->can('does') && $value->does('Model::Envoy');

    return undef;
}

sub _get_all_attributes {
    my ( $self ) = @_;

    return grep { $_->name !~ /^_/ } $self->meta->get_all_attributes;
}

sub _dispatch {
    my ( $self, $method, @params ) = @_;

    return $self->_class_dispatch($method,@params) unless ref $self;

    for my $package ( keys %{$self->_storage} ) {
        $self->_storage_instance($package)->$method();
    }
}

sub _class_dispatch {
    my ( $self, $method, @params ) = @_;

    return
        first_result { $_->$method( $self, @params ) }
        keys %{$self->storage_plugins};
}

sub _storage_instance {
    my ( $self, $package ) = @_;

    $package = $self->_get_configured_storage_class($package);
    my $conf = $self->storage_plugins->{$package};

    $self->_storage->{$package} = $package->new( %$conf, model => $self )
        unless $self->_storage->{$package};

    return $self->_storage->{$package};
}

sub _get_configured_storage_class {

    my ( $self, $package ) = @_;

    $package = _resolve_namespace($package);

    my $conf = $self->storage_plugins->{$package};
    if ( ! $conf->{_configured} ) {
        $package->configure($conf);
    }

    return $package;
}

package Model::Envoy::Meta::Attribute::Trait::Envoy;
use Moose::Role;
Moose::Util::meta_attribute_alias('Envoy');

use Moose::Util::TypeConstraints;
use List::AllUtils 'any';

has moose_class => (
    is  => 'ro',
    isa => 'Str',
);

around '_process_options' => sub { _install_types(@_) };

sub _install_types {
    my ( $orig, $self, $name, $options ) = @_;

    return unless grep { $_ eq __PACKAGE__ } @{$options->{traits} || []};

    unless( find_type_constraint('Array_of_Hashref') ) {

        subtype 'Array_of_HashRef',
            as 'ArrayRef[HashRef]';
    }
    unless ( find_type_constraint('Array_of_Object') ) {

        subtype 'Array_of_Object',
            as 'ArrayRef[Object]';
    }
    if ( $options->{isa} =~ / ArrayRef \[ (.+?) \]/x ) {
        $options->{moose_class} = $1;
        $options->{isa} = $self->_coerce_array($1);
    }
    elsif( $options->{isa} =~ / Maybe  \[ (.+?) \]/x ) {
        $options->{moose_class} = $1;
        $options->{isa} = $self->_coerce_maybe($1);
    }
    else {
        $self->_coerce_class($options->{isa});
    }

    $options->{coerce} = 1 unless $options->{moose_class} && any { $options->{moose_class} eq $_ } qw( HashRef ArrayRef );

    return $self->$orig($name,$options);
}

sub _coerce_array {
    my ( $self, $class ) = @_;

    my $type = ( $class =~ / ( [^:]+ ) $ /x )[0];

    unless( find_type_constraint("Array_of_$type") ) {

        subtype "Array_of_$type",
            as "ArrayRef[$class]";

        coerce   "Array_of_$type",
            from "Array_of_Object",
            via  { [ map { $class->build($_) } @{$_} ] },

            from 'Array_of_HashRef',
            via  { [ map { $class->new($_) } @{$_} ] };
    }

    return "Array_of_$type";
}

sub _coerce_maybe {
    my ( $self, $class ) = @_;
    my $type = ( $class =~ /\:\:([^:]+)$/ )[0];

    unless( find_type_constraint("Maybe_$type") ) {

        subtype "Maybe_$type",
            as "Maybe[$class]";

        coerce   "Maybe_$type",
            from 'Object',
            via  { $class->build($_) },

            from 'HashRef',
            via { $class->new($_) };
    }

    return "Maybe_$type";
}

sub _coerce_class {
    my ( $self, $class ) = @_;
    my $type = ( $class =~ /\:\:([^:]+)$/ )[0];

    coerce   $class,
        from 'Object',
        via  { $class->build($_) },

        from 'HashRef',
        via { $class->new($_) };
}

package Moose::Meta::Attribute::Custom::Trait::Envoy;
    sub register_implementation {
        'MooseX::Meta::Attribute::Trait::Envoy'
    };

1;
