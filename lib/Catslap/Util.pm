package Catslap::Util;

use strict;
use warnings;
use Carp qw(carp croak);
use POSIX;
use Time::HiRes qw(gettimeofday tv_interval);
use IO::Socket::INET;

sub test_config {
  my ($self,$config,$errors) = @_;

  # app.log_dir
  push @$errors, 'app.log_dir must be defined' unless defined $config->{app}->{log_dir};
  push @$errors, 'app.log_dir must be writeable' unless (defined $config->{app}->{log_dir} && -w $config->{app}->{log_dir});

  # app.log_level
  my $loglevel = $config->{app}->{log_level};
  push @$errors, 'app.log_level value invalid' unless grep /^$loglevel$/, ('fatal', 'error', 'warn', 'info', 'debug');

  # app.remote_addr_sources
  if (ref $config->{app}->{remote_addr_sources} eq 'ARRAY') {
    for my $source (@{$config->{app}->{remote_addr_sources}}) {
      push @$errors, 'app.remote_addr_sources value invalid' unless grep /^$source$/, ('x-real-ip', 'x-forwarded-for', 'tx');
    }
  } else {
    push @$errors, 'app.remote_addr_sources must be an array';
  }

  # app.default_language
  my $lang = $config->{app}->{default_language};
  push @$errors, 'app.default_language value invalid' unless grep /^$lang$/, ('en');

  # ldap.servers
  push @$errors, 'ldap.servers must be an array of LDAP URIs' unless (ref $config->{ldap}->{servers} eq 'ARRAY');

  # ldap.admins
  if (ref $config->{ldap}->{admins} eq 'ARRAY') {
    my @admins = @{$config->{ldap}->{admins}};
    for (my $i=0; $i<=$#admins; $i++) {
      push @$errors, 'ldap.admins.['.$i.'] must have \'rdn\' and \'password\' set' unless ($admins[$i]->{rdn} && $admins[$i]->{password});
    }
  } else {
    push @$errors, 'ldap.admins must be a defined array';
  }

  # ldap.clients
  if (ref $config->{clients} eq 'ARRAY') {
    my @clients = @{$config->{clients}};
    for (my $i=0; $i<=$#clients; $i++) {
      push @$errors, 'clients.['.$i.'] must have \'name\' and \'token\' set' unless ($clients[$i]->{name} && $clients[$i]->{token});
    }
  } else {
    push @$errors, 'clients must be a defined array';
  }

  return (@$errors?0:1);
}

sub randstr {
  my $self = shift;
  my $length = shift || 32;
  my $adduc = shift;
  $length = int($length);
  $length = 32 if ($length <= 0);
  $length = 256 if ($length > 256);
  my @chars = ('a'..'z', '0'..'9');
  @chars = (@chars, ('A'..'Z')) if $adduc;
  my ($sec,$msec) = gettimeofday;
  srand($sec.$msec);
  my $str;
  $str .= $chars[rand @chars] for (1 .. $length);
  return $str;
}

sub duration {
  my $self = shift;
  my $start_time = shift || 0;
  return ($start_time > 0 ? sprintf('%.5f', tv_interval($start_time, [gettimeofday])) : 0.0);
}

sub merge_hashref { shift; return { map %$_, grep ref $_ eq 'HASH', @_ } }

sub new {
  my $class = shift;
  my $self = {};
  bless( $self, ( ref($class) || $class ) );
  return $self;
}

1;
