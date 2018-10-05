package t::Helper;
use Mojo::Base -strict;
use Mojolicious;
use Test::Mojo;
use Test::More;
use Mojo::Util qw(dumper encode);
use Mojo::File;

# Sourced from https://github.com/ldidry/mojolicious-plugin-configrw
sub write_config {
  my ($self,$path,$config) = @_;
  my $conf = dumper($config);
     $conf = substr($conf, 8);
     $conf =~ s/\n            /\n/gm;
     $conf =~ s/\n +(.*)$/\n$1/;
  my $file = Mojo::File->new(encode('UTF-8', $path));
  $file->spurt($conf);
}

1;
