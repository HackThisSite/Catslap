package Catslap;
use Mojo::Base 'Mojolicious';
use Mojo::Util qw(secure_compare);
use Mojo::JSON qw(encode_json);
use POSIX qw(strftime);
use Time::HiRes qw(gettimeofday);
use Catslap::Util;
use Catslap::Model::Client;

#BEGIN { $ENV{MOJO_I18N_DEBUG} = 1 };

sub startup {
  my $app = shift;

  # Set 'moniker' (namespace)
  # Must be set before config is loaded
  $app->moniker('catslap');

  # Load Catslap::Util
  my $util_obj = Catslap::Util->new;
  $app->helper(util => sub { state $util = $util_obj });

  # Set plugin namespace
  push @{$app->plugins->namespaces}, 'Catslap::Plugin';

  # Load and test config
  my $config = $app->plugin('Config' => {default => {
    app => {
      log_level => 'info',
      host => 'localhost',
      # "c-a-t" 5-fingers
      # or 311's best album year?
      # You decide. ;)
      port => 31195,
      tls => 0,
      remote_addr_sources => ['tx'],
      default_language => 'en',
    },
  }});
  my $cferr = [];
  unless ($util_obj->test_config($config, $cferr)) {
    print "FATAL: Errors in configuration:\n";
    print sprintf("> %s\n", $_) for (@$cferr);
    print "\n";
    die;
  }

  $app->secrets([$util_obj->randstr()]);

  # 2.2 Establish logging facility
  $app->log(Mojo::Log->new(path => $config->{app}->{log_dir}.'/catslap.log', level => $config->{app}->{log_level}));

  # Here we go!
  $app->log->info('Catslap started');

  # Localization for error messages
  $app->plugin('I18N' => {default => $config->{app}->{default_language}});

  # Parse client IP address
  $app->plugin('RemoteAddr' => {order => $config->{app}->{remote_addr_sources}});

  # HTTP Basic Auth
  $app->plugin('http_basic_auth', {
    realm => 'Catslap',
    invalid => sub {
      my $c = shift;
      return (json => sub {
        if ($c->req->headers->header('Authorization')) {
          $c->render(json => {
            result => 'error',
            error => $c->l('error_access_denied'),
          });
        } else {
          $c->app->log->warn(sprintf('Missing HTTP Basic Auth credentials - IP: %s', $c->remote_addr));
          $c->render(json => {
            result => 'error',
            error => $c->l('error_missing_credentials'),
          });
        }
      });
    },
    validate => sub {
      my ($c,$name,$token,$realm) = @_;
# Needed?
#      return 0 unless ($realm eq 'Catslap');
      # 1. Validate client name and token
      my $client = undef;
      foreach my $cl (@{$c->app->config->{clients}}) {
        if (secure_compare($cl->{name}, $name) && secure_compare($cl->{token}, $token)) {
          $client = Catslap::Model::Client->new($cl);
          last;
        }
      }
      unless ($client) {
        $c->app->log->warn(sprintf('Invalid HTTP Basic Auth credentials - IP: %s; Client ID: %s', $c->remote_addr, $name));
        return 0;
      }
      # 2. Check IP range
      unless ($client->is_ip_allowed($c->remote_addr)) {
        $c->app->log->warn(sprintf('Denied IP address - Client: %s; IP: %s; Allow: %s', $name, $c->remote_addr, join(', ', @{$client->allow_from})));
        return 0;
      }
      # Valid
      $c->stash(client => $client);
#  $c->app->log->debug($c->dumper($client));
      return 1;
    }
  });

  # Enforce JSON responses
  $app->hook(before_dispatch => sub {
    my $c = shift;
    $c->stash(format => 'json');
  });

  # Log requests
  # Format: remote_addr client_id "request" http_status bytes_sent "user_agent"
  $app->hook(after_dispatch => sub {
    my $c = shift;
    my $client = $c->stash('client');
    $c->app->log->info(sprintf('Request: %s %s "%s %s" %d %d "%s"',
      $c->remote_addr,
      ($client ? $client->name : '-'),
      uc $c->req->method,
      $c->req->url->path_query,
      $c->res->code,
      $c->res->body_size,
      $c->req->headers->user_agent
    ));
  });

  # Intercept errors and render JSON
  $app->hook(before_render => sub {
    my ($c, $args) = @_;
    return unless my $template = $args->{template};
    if ($template eq 'exception') {
      my ($sec,$msec) = gettimeofday;
      my @gmtime = gmtime($sec);
      my $traceid = sprintf('%d-%d-%s', $sec, $msec, $c->util->randstr(12, 1));
      $c->stash(traceid => $traceid, timestamp => strftime('%Y-%m-%dT%H:%M:%SZ%z', @gmtime));
      my $exfile = $c->config->{app}->{log_dir}.'/exception_'.$traceid.'.json';
      open(my $exh, '>'.$exfile) or die('Fatal: Cannot write trace file, directory not writeable: '.$c->config->{app}->{log_dir});
      print $exh encode_json({
        timestamp       => sprintf('%.4f', $sec.'.'.$msec),
        stack           => $c->dumper($args->{exception}),
        request         => $c->dumper($c->req),
      });
      close $exh;
      $c->app->log->error('Exception trace dump written to '.$exfile);
      my $json = {
        timestamp => $sec,
        result => 'error',
        error => $c->l('error_500'),
        trace_id => $traceid,
      };
      $json->{exception} = $args->{exception} if ($c->app->mode eq 'development');
      $args->{json} = $json;
    } elsif ($template eq 'not_found') {
      $c->app->log->error(sprintf('404 Not Found - IP: %s; Request: "%s %s"', $c->remote_addr, uc $c->req->method, $c->req->url->path));
      $args->{json} = {
        result => 'error',
        error => $c->l('error_404'),
      };
    }
  });

  # Define routes and their controllers
  my $routes = $app->routes;
  my $r = $routes->under('/' => sub {
    my $c = shift;
    return undef unless $c->basic_auth();
    return 1;
  });
  $r->any('/')->to('lists#index')->name('index');
  $r->any('/admins')->to('lists#admins')->name('admins');
  $r->any('/authenticate')->to(controller => 'LDAP', action => 'process', call => 'bind')->name('authenticate');
  $r->any('/bind')->to(controller => 'LDAP', action => 'process', call => 'bind')->name('bind');
  $r->any('/search')->to(controller => 'LDAP', action => 'process', call => 'search')->name('search');
  $r->any('/add')->to(controller => 'LDAP', action => 'process', call => 'add')->name('add');
  $r->any('/modify')->to(controller => 'LDAP', action => 'process', call => 'modify')->name('modify');
  $r->any('/delete')->to(controller => 'LDAP', action => 'process', call => 'delete')->name('delete');
}

1;
