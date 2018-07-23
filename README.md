# Model::Envoy

A Moose Role that can be used to build a model layer which keeps business logic separate from your storage layer.

## Synopsis

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

## Setting up storage

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

## Model attributes

Model::Envoy classes use normal Moose attribute declarations. Depending on the storage layer plugin, they may add attribute traits or other methods
your models need to implement to indicate how each attribute finds its way into and out of storage.

### Attribute Type Coercion with the 'Envoy' trait

This trait is handy for class attributes that represent other Model::Envoy
enabled classes (or arrays of them).  It will allow you to pass in hashrefs
(or arrays of hashrefs) to those attributes and have them automagically elevated
into an instance of the intended class.

    has 'parts' => (
        is => 'rw',
        isa => 'ArrayRef[My::Model::Part]',
        traits => ['Envoy'],
    );

## Class Methods

### build()

`build` is a more flexible version of `new`.  It can take a standard hashref of properties just as `new` would, but it can also take
classes that are used by your storage layer plugins and, if those plugins support this, convert them into an instance of your model object.

### get\_storage('Plugin')

Passes back the storage plugin specified by `$storage_package` being used by the class. Follows the same namespace resolution
process as the instance method below.

## Instance Methods

### save()

Save the instance to your persistent storage layer.

### update($hashref)

Given a supplied hashref of attributes, bulk update the attributes of your instance object.

### delete()

Remove the instance from your persistent storage layer.

### dump()

Provide an unblessed copy of the datastructure of your instance object.

### get\_storage('Plugin')

Given the namespace of a storage plugin, return the instance of it that's backing the current object.  If the plugin is in the
`Model::Envoy::Storage::` namespace, it can be abbreviated:

    $model->get_storage('DBIC')  # looks for Model::Envoy::Storage::DBIC

otherwise, prefix your plugin name with a `+` to get something outside of the default namespace:

    $model->get_storage('+My::Storage::WhatsIt');

### in\_storage('Plugin')

Returns true if the storage plugin reports your model is saved in its storage mechanism.

## Aggregate methods

For operations that fetch and search for one or more models, see `Model::Envoy::Set`.
