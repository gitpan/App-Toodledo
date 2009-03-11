#!perl -T
use strict;
use warnings;

use Test::More tests => 10;
use Test::NoWarnings;
use Test::Exception;
use Test::MockModule;

my $CLASS;
my $USERID   = 'username';
my $PASSWORD = 'password';
my $KEY      = 'myKey';

BEGIN { $CLASS = 'App::Toodledo'; use_ok $CLASS }

my $todo = $CLASS->new;

my ($host, $func);
my $mock = Test::MockModule->new( $CLASS );
$mock->mock( _make_client => sub { $host = $_[1]; bless {}, 'REST::Client' } );
$mock->mock( call_func => sub { $func = $_[1] } );
$mock->mock( _key_from_context => sub { $KEY } );

throws_ok { $todo->login } qr/Parameter/;

throws_ok { $todo->login( $USERID) } qr/Parameter/;

lives_ok { $todo->login( $USERID, $PASSWORD ) };

is $host, 'api.toodledo.com';
is $func, 'getToken';

is $todo->userid, $USERID;

is $todo->password, $PASSWORD;

is $todo->key, $KEY;
