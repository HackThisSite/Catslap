```
{

  listen => {
  
    host => 'localhost',
    
    port => 31195,
    
    tls => 1,
    
    tls_key => '/path/to/cert.key',
    
    tls_cert => '/path/to/cert.crt',
  
  },

  ldap => {

    host => 'localhost',

    port => 389,

    tls => 1,

    tls_cacert => '/path/to/ca-cert.crt',

    admin_bind_dn => 'cn=Service-Acct,ou=Services,dc=example,dc=com',
    
    admin_bind_passwd => 'd4280da04e4458824e3e4a981a05957f',

  },

  clients => [

    {

      name => 'nodejs-app-1',

      token => '0d1372ea-a937-490d-ad37-862a91c5fbaf',

      secret => 'b6bb165d9a9b0a38c369be2e0d7f3db4',

      acl => {

        # Default: 1
        can_bind => 1,
        
        # Default: 0
        can_search => 0,
        
        # Overrides 'can_search'
        # Default: 0
        can_search_as_admin => 0,
        
        # Default: 0
        can_add => 0,
        
        # Default: 0
        can_modify => 0,
        
        # Overrides 'can_modify'
        # Default: 0
        can_modify_as_admin => 0,
        
        # Default: 0
        can_delete => 0,

      },

    },

  ],

};
```