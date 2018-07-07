package My::Widget;

    use Moose;
    extends 'My::BasePart';

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
        isa => 'ArrayRef[My::Part]',
        traits => ['DBIC'],
        rel => 'has_many',
    );

1;