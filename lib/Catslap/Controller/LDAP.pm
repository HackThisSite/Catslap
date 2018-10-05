package Catslap::Controller::LDAP;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw(encode_json decode_json);
use Catslap::Model::LDAP;

sub process {
  my $c = shift;
  my $call = $c->stash('call');
  my $client = $c->stash('client');

  # Validate access
  if (
    ($call eq 'bind' && !$client->acl('can_bind')) ||
    ($call eq 'search' && !$client->acl('can_search')) ||
    ($call eq 'add' && !$client->acl('can_add')) ||
    ($call eq 'modify' && !$client->acl('can_modify')) ||
    ($call eq 'delete' && !$client->acl('can_delete'))
  ) {
    $c->app->log->warn(sprintf('Unauthorized %s attempt - IP: %s; Client: %s', $call, $c->remote_addr, $client->name));
    $c->render(json => {
      result => 'error',
      error => $c->l('error_unauthorized'),
    }, status => 403);
    return 0;
  }

  #  my $bindrdn = $c->param('bindrdn');
  #  my $password = $c->param('password');

  # Connect to LDAP
  my $ldap = Catslap::Model::LDAP->new($c->app);
  unless ($ldap->connect()) {
    $c->render(json => {
      result => 'error',
      msg => $c->l('error_ldap_connect'),
    }, status => 500);
    return undef;
  }

  # Perform bind
#  my $bind = $ldap->bind($user, $pass);

  ### CALL: bind
  if ($call eq 'bind') {
    return $c->render(json => {
      TODO => $call,
    });
  }

  my $result = {};

  ### CALL: search
  if ($call eq 'search') {
    $result->{foo} = 'search';
  }

  ### CALL: add
  if ($call eq 'add') {
    $result->{foo} = 'add';
  }

  ### CALL: modify
  if ($call eq 'modify') {
    $result->{foo} = 'modify';
  }

  ### CALL: delete
  if ($call eq 'delete') {
    $result->{foo} = 'delete';
  }

  # Disconnect from LDAP
  $ldap->disconnect();

  # Send result to client
  $c->render(json => {
    TODO => $call,
    result => $result,
    foo => $c->l('desc_index'),
  });
}

1;
