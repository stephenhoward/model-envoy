package Model::Envoy::Storage;

our $VERSION = '0.1.1';

use Moose;

has 'model' => (
    is => 'rw',
    does => 'Model::Envoy',
    required => 1,
    weak_ref => 1,
);

sub configure {
    my ( $class, $conf ) = @_;

    $conf->{_configured} = 1;
}

sub build {

    return undef;
}

=head1 Storage Plugins

=head2 Configuration

=head3 Declaration

    with 'Model::Envoy' => { storage => {
        'DBIC' => {
            schema => sub {
                ... connect to database here ...
            }
        }
    } };

=head2 Instantiation

When C<Model::Envoy> created an instance of your plugin, it will pass in 

=head2 Required Methods

=head3 save

=head3 delete

=head2 Optional Methods

=head3 C<configure>

When your models first need to connect to storage, they will call C<configure>
on your storage class to give it a chance to perform setup that will be needed
by all of your instance objects (a database handle, for example).

=head3 C<build>

=cut

1;