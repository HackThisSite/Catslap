package Catslap::Model::LDAP;
use strict;
use warnings;
use Mojo::JSON qw(encode_json decode_json);
use Time::HiRes qw(gettimeofday);
use Net::LDAP;
use Net::LDAP::Control::PasswordPolicy;
use Net::LDAP::Constant qw( LDAP_INVALID_CREDENTIALS LDAP_CONTROL_PASSWORDPOLICY LDAP_PP_PASSWORD_EXPIRED LDAP_PP_ACCOUNT_LOCKED LDAP_PP_CHANGE_AFTER_RESET );
use Net::LDAP::Util qw(ldap_error_text ldap_error_name ldap_error_desc);

# Instantiator
sub new {
  my $class = shift;
  my $self = {};
  bless( $self, ( ref($class) || $class ) );
  $self->{app} = shift;
  $self->{config} = $self->{app}->{config}->{ldap};
  return $self;
}

# Select a random server from the config
sub _server {
  my $self = shift;
  my @servers = @{$self->{config}->{servers}};
  # Skip random if only one is defined
  return $servers[0] if ($#servers == 0);
  # Return random server
  my ($sec,$msec) = gettimeofday;
  srand($sec.$msec);
  return $servers[rand @servers];
}

# Connect to LDAP
sub connect {
  my $self = shift;
  my $server = $self->_server();
  $self->{app}->log->debug('Connecting to LDAP: '.$server);
  $self->{ldap} = Net::LDAP->new($server);
  return ($self->{ldap}?1:0);
}

sub disconnect {
  my $self = shift;
  $self->{app}->log->debug('Disconnecting from LDAP');
  return $self->{ldap}->disconnect;
}

sub bind {
  my $self = shift;
  my ($rdn,$password) = @_;
  $self->{app}->log->debug('Performing bind on: '.$rdn);
  my $pp = Net::LDAP::Control::PasswordPolicy->new;

  my (@warns, @crits);
  my $authsuccess = 0;

  # TODO: Review and re-test all this

  # Attempt to bind
  my $mesg = $self->{ldap}->bind($rdn, password => $password, control => [ $pp ]);
  if ($mesg->code == LDAP_INVALID_CREDENTIALS) {
#    output('Bind: Invalid credentials',2);
    push(@crits, 'LDAP_INVALID_CREDENTIALS');
  } elsif ($mesg->code) {
#    output('Bind: Error: '.$mesg->code,2);
    push(@crits, 'LDAP_ERR:'.$mesg->code);
  } else {
#    output('Bind: Success',2);
    $authsuccess = 1;
  }

  # Retrieve Password Policy return values, if any
  my $resp = $mesg->control(LDAP_CONTROL_PASSWORDPOLICY); # 1.3.6.1.4.1.42.2.27.8.5.1
  if ($resp) {
#    output('Password Policy responses returned',2);
    # Check if expiring soon
    my $exp = $resp->time_before_expiration; # $exp is in seconds
    push(@warns, "LDAP_PP_PASSWORD_EXPIRING:$exp") if ($exp);

    # Check if they are in the grace period
    my $grace = $resp->grace_authentications_remaining; # $grace is the amount of logins they have left
    push(@warns, "LDAP_PP_GRACE_LOGINS_LEFT:$grace") if ($grace);

    # Check for other Password Policy errors
    my $pperr = $resp->pp_error;
    if ($pperr) {
      push(@crits, "LDAP_PP_PASSWORD_EXPIRED") if ($pperr == LDAP_PP_PASSWORD_EXPIRED);
      push(@crits, "LDAP_PP_ACCOUNT_LOCKED") if ($pperr == LDAP_PP_ACCOUNT_LOCKED);
      push(@crits, "LDAP_PP_CHANGE_AFTER_RESET") if ($pperr == LDAP_PP_CHANGE_AFTER_RESET);
    }
  }

  # Check for banned state (expired account)
  if ($authsuccess) {
#    output('Checking if banned',2);
    my $search = $self->{ldap}->search(base => 'ou=People,dc=example,dc=com', scope => 'sub', filter => '('.$rdn.')', attrs => [ 'shadowExpire' ]);
    print "LDAP SEARCH ERROR ".$search->code().": ".$search->error if ($search->code());
    my $curday = int(time()/(24*60*60));
    foreach my $entry ($search->entries) {
      if ($entry->exists('shadowExpire')) {
        push(@crits, 'LDAP_BANNED') if ($entry->get_value('shadowExpire') != -1 && $entry->get_value('shadowExpire') lt $curday);
      }
    }
  }

  # Assemble hashref
  my $ret = {};
  $ret->{'warns'} = [@warns] if (@warns);
  $ret->{'crits'} = [@crits] if (@crits);
  if ($#crits >= 0) {
    $ret->{'exit'} = 2;
    $ret->{'mesg'} = 'CRITICAL';
  } elsif ($#warns >= 0) {
    $ret->{'exit'} = 1;
    $ret->{'mesg'} = 'WARNING';
  } else { # No warnings or criticals
    if ($authsuccess) {
      $ret->{'exit'} = 0;
      $ret->{'mesg'} = 'OK';
    } else {
      $ret->{'exit'} = 3;
      $ret->{'mesg'} = 'UNKNOWN';
    }
  }
  return $ret;
}

sub unbind {
  my $self = shift;
  return $self->{ldap}->unbind;
}

sub search {
  my $self = shift;
}

sub add {
  my $self = shift;
}

sub modify {
  my $self = shift;
}

sub delete {
  my $self = shift;
}

1;
