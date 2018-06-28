package My::Envoy::Base;

    use Moose;
    use My::DB;

    my $schema;

    with 'Model::Envoy' => { storage => {
        'DBIC' => {
            schema => sub {
                warn "CONNECTING";
                $schema ||= My::DB->db_connect('/tmp/envoy');
            }
        }
    } };

1;