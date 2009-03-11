#!perl -T
use strict;
use warnings;

use Test::More tests => 5;
use Test::NoWarnings;
use Test::Exception;
use Test::MockModule;

my $CLASS;
my $FUNC = 'myFunc';
my $DOC = 'XML document';
my $USERID = 'username';

BEGIN { $CLASS = 'App::Toodledo'; use_ok $CLASS }

my $todo = $CLASS->new;

throws_ok { $todo->call_func( $FUNC ) } qr/login/;

my $mock_client = Test::MockModule->new( 'REST::Client' );
$todo->client( REST::Client->new );

my $func;
$mock_client->mock( GET => sub { $func = $_[1] } );
$mock_client->mock( responseXpath => sub { $DOC } );

my $doc;
my $mock = Test::MockModule->new( $CLASS );
$mock->mock( _context_from_doc => sub { $doc = shift } );

$todo->userid( $USERID );
$todo->call_func( $FUNC );

is $func, "/api.php?method=myFunc;userid=$USERID";

is $doc, $DOC;
