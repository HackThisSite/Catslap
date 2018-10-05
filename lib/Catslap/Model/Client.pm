package Catslap::Model::Client;
use strict;
use warnings;
use Net::CIDR::Lite;

# Instantiator
sub new {
  my $class = shift;
  my $self = {};
  bless( $self, ( ref($class) || $class ) );
  my $config = shift;

  $self->{name} = $config->{name};
  $self->{token} = $config->{token};
  $self->{allow_from} = $config->{allow_from} || ['0.0.0.0/0'];
  $self->{use_admin} = $config->{use_admin} || 'default';

  $self->{acl} = {
    can_choose_admin => (defined $config->{acl}->{can_choose_admin} ? $config->{acl}->{can_choose_admin} : 1),
    can_view_admins => (defined $config->{acl}->{can_view_admins} ? $config->{acl}->{can_view_admins} : 0),
    can_bind => (defined $config->{acl}->{can_bind} ? $config->{acl}->{can_bind} : 1),
    can_search => (defined $config->{acl}->{can_search} ? $config->{acl}->{can_search} : 0),
    can_add => (defined $config->{acl}->{can_add} ? $config->{acl}->{can_add} : 0),
    can_modify => (defined $config->{acl}->{can_modify} ? $config->{acl}->{can_modify} : 0),
    can_delete => (defined $config->{acl}->{can_delete} ? $config->{acl}->{can_delete} : 0),
  };

  if (defined $config->{acl}->{can_search_as_admin}) {
    $self->{acl}->{can_search} = 1 if $config->{acl}->{can_search_as_admin};
    $self->{acl}->{can_search_as_admin} = $config->{acl}->{can_search_as_admin};
  } else {
    $self->{acl}->{can_search_as_admin} = 0;
  }

  if (defined $config->{acl}->{can_modify_as_admin}) {
    $self->{acl}->{can_modify} = 1 if $config->{acl}->{can_modify_as_admin};
    $self->{acl}->{can_modify_as_admin} = $config->{acl}->{can_modify_as_admin};
  } else {
    $self->{acl}->{can_modify_as_admin} = 0;
  }

  return $self;
}

# Get name
sub name {
  my $self = shift;
  return $self->{name};
}

# Get token
sub token {
  my $self = shift;
  return $self->{token};
}

# Get allowed IP whitelists
sub allow_from {
  my $self = shift;
  return $self->{allow_from};
}

# Validate if IP address is within whitelists
sub is_ip_allowed {
  my ($self,$ip) = @_;
  my $cidr = Net::CIDR::Lite->new;
  foreach (@{$self->{allow_from}}) {
    $cidr->add_any($_);
  }
  return $cidr->find($ip);
}

# Get a named ACL
sub acl {
  my ($self,$acl) = @_;
  return $self->{acl}->{$acl};
}

1;
