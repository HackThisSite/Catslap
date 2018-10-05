use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use File::Temp qw(tempfile tempdir);
use t::Helper;

$ENV{MOJO_MODE} = 'development';
$ENV{MOJO_CONFIG} = '/tmp/foobar.conf';

my $test_config = {
  app => {
    log_dir => '/tmp',
    log_level => 'debug',
    remote_addr_sources => [
      'tx',
    ],
    default_language => 'en',
  },
  ldap => {
    servers => [
      'ldap://localhost:389',
    ],
    admins => [
      {
        id => 'admin1',
        rdn => 'cn=admin1,ou=service-accounts,dc=example,dc=com',
        password => 'Adm1nPassw0rd',
        allow_clients => [
          'nodejs-app-1',
          'python-app-1',
        ],
      },
    ],
  },
  clients => [
    {
      name => 'nodejs-app-1',
      token => 'really-loooong-token-aaaaaaaaaaaaaabbbbbbbbbbbcccccccccccccccc',
      allow_from => [
        '0.0.0.0/0',
      ],
      use_admin => 'default',
      acl => {
        can_choose_admin => 0,
        can_bind => 1,
        can_search => 0,
        can_search_as_admin => 0,
        can_add => 0,
        can_modify => 0,
        can_modify_as_admin => 0,
        can_delete => 0,
        can_view_admins => 0,
      },
    },
  ],
};

t::Helper->write_config($ENV{MOJO_CONFIG}, $test_config);

my $t = Test::Mojo->new('Catslap');

# 401 WWW-Authenticate notice
$t->get_ok('/')
  ->status_is(401)
  ->header_like('WWW-Authenticate' => qr/basic realm="catslap"/i)
  ->content_like(qr/Missing/i);

done_testing();
