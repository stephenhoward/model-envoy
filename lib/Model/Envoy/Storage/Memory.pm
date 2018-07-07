package Model::Envoy::Storage::Memory;

our $VERSION = '0.1.1';

=head1 Model::Envoy::Storage::DBIC

A Moose Role that adds a DBIx::Class persistence layer to your Moose class

=head2 Traits

This role implements one trait:

=head3 DBIC

Marking an attribute on your object with the 'DBIC' trait tells this role that it is
backed by a DBIx::Class ResultClass column of the same name.  It also allows for
a few custom options you can apply to that attribute:

=over

=item primary_key => 1

Indicates that this attribute corresponds to the primary key for the database record

=item rel => 'rel_type'

Indicates that the attribute is a relationship to another model or a list of models. Possible
values for this option are

=over

=item belongs_to

=item has_many

=item many_to_many

=back

=item mm_rel => 'bridge_name'

For many-to-many relationships it is necessary to indicate what class
provides the linkage between the two ends of the relationship ( the linking class
maps to the join table in the database).

=back


=cut

use Moose;
use Scalar::Util 'blessed';
use MooseX::ClassAttribute;

extends 'Model::Envoy::Storage';

class_has 'store' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    default  => sub { }
);

=head2 Methods

=head3 new_from_db( $dbic_result, [$no_rel] )

Takes a DBIx::Class result object and, if it's class matches your class's dbic()
method, attempts to build a new instance of your class based on the $dbic_result
passed in.

The `no_rel` boolean option prevents the creation process from traversing
attributes marked as relationships, minimizing the amount of data pulled
from the database and the number of new class instances created.

Returns the class instance if successful.

=cut

=head3 save()

Performs either an insert or an update for the model, depending on whether
there is already a record for it in the database.

Returns the calling object for convenient chaining.

=cut

sub save {
    my ( $self ) = @_;

    $self->store->{ $self->model->id } = $self->model->dump;

    return $self;
}

=head3 db_delete()

Deletes the persistent copy of the current model from the database, if has
been stored there.

Returns nothing.

=cut

sub delete {
    my ( $self ) = @_;

    delete $self->store->{ $self->model->id };

    return;
}

=head3 in_storage()

=cut

sub in_storage {
    my ( $self ) = @_;

    return exists $self->store->{ $self->model->id };
}

1;