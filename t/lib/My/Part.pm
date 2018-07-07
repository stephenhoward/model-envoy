package My::Part;

    use Moose;
    extends 'My::BasePart';

    sub dbic { 'My::DB::Result::Part' }

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

    has 'widget' => (
        is => 'rw',
        isa => 'Maybe[My::Widget]',
        traits => ['DBIC'],
        rel => 'belongs_to',
    );

1;