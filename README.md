# Model::Envoy

A Moose Role that can be used to build a model layer that keeps business logic separate from your storage layer.

## Synopsis

    package My::Envoy::Widget;

        use Moose;
        with 'Model::Envoy';

        use My::DB;

        sub dbic { 'My::DB::Result::Widget' }

        my $schema;

        sub _schema {
            $schema ||= My::DB->db_connect(...);
        }

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
            isa => 'ArrayRef[My::Envoy::Part]',
            traits => ['DBIC','Envoy'],
            rel => 'has_many',
        );

    package My::Envoy::Models;

    use Moose;
    with 'Model::Envoy::Set';

    sub namespace { 'My::Envoy' }


    ....then later...

    my $widget = My::Envoy::Models->m('Widget')->build({
        id => 1
        name => 'foo',
        no_storage => 'bar',
        parts => [
            {
                id => 2,
                name => 'baz',
            },
        ],
    })

## Traits

### DBIC

See \`Model::Envoy::Storage::DBIC\`;

### Envoy

This trait is handy for class attributes that represent other Model::Envoy
enabled classes (or arrays of them).  It will allow you to pass in hashrefs
(or arrays of hashrefs) to those attributes and have them automagically elevated
into an instance of the intended class.

## Methods

### save()

Save the instance to your persistent storage layer.

### update($hashref)

Given a supplied hashref of attributes, bulk update the attributes of your instance object.

### delete()

Remove the instance from your persistent storage layer.

### dump()

Provide an unblessed copy of the datastructure of your instance object.
