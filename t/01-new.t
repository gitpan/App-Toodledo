#!perl -T

use Test::More tests => 5;
use Test::NoWarnings;
use Test::Exception;

my $CLASS;
BEGIN { $CLASS = 'App::Toodledo'; use_ok( $CLASS ) }
use App::Toodledo;

my $todo;

lives_ok { $todo = $CLASS->new };
isa_ok $todo, $CLASS;
can_ok $todo, qw(login);
