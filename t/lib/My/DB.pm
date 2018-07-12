package My::DB;

use strict;
use warnings;

use base 'DBIx::Class::Schema';

my $filename;

sub db_connect {
    my( $schema, $file ) = @_;

    if ( ! $filename ) {
        $filename = $file || '/tmp/testdata';
        $filename .= '-'.rand(time);
    }

    return $schema->connect( "dbi:SQLite:dbname=$filename",'','');
}

sub cleanup {

    unlink $filename if $filename;
}

__PACKAGE__->load_namespaces;

1;
