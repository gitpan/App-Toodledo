#!perl -T
use strict;
use warnings;

use Test::More tests => 4;
use Test::NoWarnings;
use Test::Exception;

my $CLASS;
my $FUNC   = 'myFunc';
my $USERID = 'username';
my $KEY    = 'myKey';

BEGIN { $CLASS = 'App::Toodledo'; use_ok $CLASS }

my $todo = $CLASS->new;
$todo->userid( $USERID );

my $path = $todo->_make_path( $FUNC );
is $path, "/api.php?method=$FUNC;userid=$USERID";

$todo->key( $KEY );
$path = $todo->_make_path( $FUNC );
is $path, "/api.php?method=$FUNC;key=$KEY";
