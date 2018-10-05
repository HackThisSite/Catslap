package Catslap::I18N::en;
use Mojo::Base 'Catslap::I18N';

our %Lexicon = (
  rtdesc_index => 'List of all functions for this REST endpoint',
  rtdesc_admins => 'List of all configured LDAP administrative bind accounts',
  rtdesc_authenticate => 'Alias of \'/bind\'',
  rtdesc_bind => 'Attempt an LDAP bind and return results including Password Policy controls',
  rtdesc_search => 'Perform one or more LDAP search queries',
  rtdesc_add => 'Add one or more LDAP objects',
  rtdesc_modify => 'Modify one or more LDAP objects',
  rtdesc_delete => 'Delete one or more LDAP objects',
  error_404 => '404 Not Found',
  error_500 => '500 Internal Server Error',
  error_access_denied => 'Access denied - not authorized',
  error_missing_credentials => 'Missing HTTP Basic Auth credentials',
  error_unauthorized => 'Not authorized for this function',
  error_ldap_connect => 'Cannot connect to LDAP server',
);

1;
