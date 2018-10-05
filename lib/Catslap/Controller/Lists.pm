package Catslap::Controller::Lists;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw(encode_json decode_json);
use re 'regexp_pattern';

# List all endpoints
sub index {
  my $c = shift;
  my $client = $c->stash('client');
  # Log this request
  $c->app->log->info(sprintf('"%s %s" from %s @ %s', uc $c->req->method, $c->req->url->path, $client->{name}, $c->remote_addr));
  my $list = [];
  _walk($c, $_, $list) for @{$c->app->routes->children};
  $c->render(json => $list);
}

# List all admins
sub admins {
  my $c = shift;
  my $client = $c->stash('client');

  # Log this request
  $c->app->log->info(sprintf('"%s %s" from %s @ %s', uc $c->req->method, $c->req->url->path, $client->{name}, $c->remote_addr));

  # Verify access
  unless ($client->{acl}->{can_view_admins}) {
    $c->app->log->warn(sprintf('Unauthorized admins list attempt - IP: %s; Client ID: %s', $c->remote_addr, $client->{name}));
    $c->render(json => {
      status => 'error',
      error => $c->l('error_unauthorized'),
    }, status => 403);
    return 0;
  }

  # Assemble list of admins and print
  my $admins = [];
  foreach my $adm (@{$c->app->config->{ldap}->{admins}}) {
    push @$admins, {
      id => $adm->{id},
      rdn => $adm->{rdn},
    };
  }
  $c->render(json => $admins);
}

# Walk routes and form list of endpoints
sub _walk {
  my ($c, $route, $list) = @_;
  unless ($route->inline) {
    push @$list, {
      path => $c->url_for($route->name)->path,
      url => $c->url_for($route->name)->to_abs,
      description => $c->l('rtdesc_'.$route->name),
    };
  }
  _walk($c, $_, $list) for @{$route->children};
}

1;
