package My::DynamicProperty;

use base 'DBIx::Class';

sub insert {

    my $self = shift;

    if ( ! defined $self->name ) {
        $self->name('name set');
    }

    return $self->next::method(@_);
    
}

1;

package My::DB::Result::DynamicWidget;

use Moose;

extends 'DBIx::Class::Core';

__PACKAGE__->load_components( '+My::DynamicProperty' );

__PACKAGE__->table('widgets');
__PACKAGE__->add_columns(

    'id'      => { data_type => 'integer', is_nullable => 0, },
    'name'    => { data_type => 'text',    },
);
__PACKAGE__->set_primary_key('id');

sub sql {
    return 'create table widgets ( id integer not null primary key, name varchar)';
}

1;
