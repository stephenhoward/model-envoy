package My::BasePart;

    use Moose;
    extends 'Model::Envoy::Storage::DBIC';

    use My::DB;

    my $schema;

    sub _schema {
        $schema ||= My::DB->db_connect('/tmp/dbic');
    }

1;