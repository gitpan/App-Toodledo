package App::Toodledo;
use strict;
use warnings;

our $VERSION = '0.07';

use Carp;
use File::Spec;
use Readonly;
use Digest::MD5 'md5_hex';
use REST::Client;
use Moose;
use MooseX::Method;
use XML::LibXML;
use POSIX qw(strftime);
use File::HomeDir;
use Date::Parse;
use YAML qw(LoadFile);

use App::Toodledo::Task;
use App::Toodledo::Folder;


Readonly my $HOST   => 'api.toodledo.com';
Readonly my $RCFILE => '.toodledorc';

has userid   => ( is => 'rw', isa => 'Str', );
has password => ( is => 'rw', isa => 'Str', );
has key      => ( is => 'rw', isa => 'Str', );
has client   => ( is => 'rw', isa => 'REST::Client', );


method login => positional (
  { isa => 'Str', required => 1 },
  { isa => 'Str', required => 1 }, ) => sub
{
  my ($self, $userid, $password) = @_;

  $self->userid( $userid );
  $self->password( $password );
  $self->client( $self->_make_client( $HOST ) );
  $self->key( $self->_make_key );
};


sub login_from_rc
{
  my $self = shift;

  my $rcfile = $self->_rcfile;
  _debug( "Getting login information from $rcfile\n" );
  $self->login( $rcfile->{userid}, $rcfile->{password} );
}


sub _rcfile
{
  my $file = File::Spec->catfile( File::HomeDir->my_home, $RCFILE );
  LoadFile( $file );
}


method foreach_task => positional (
  { isa => 'CodeRef', required => 1 },
  { isa => 'HashRef', default => {} } ) => sub
{
  my ($self, $callback, $optref) = @_;

  my $context = $self->call_func( getTasks => $optref );
  for my $element ($context->findnodes( 'tasks/task' ))
  {
    my $task = _make_task( $element );
    _debug( "Calling callback for task ID ", $task->id, "\n" );
    $callback->( $self, $task );
  }
};


sub _make_task
{
  my $element = shift;

  my @nodes = $element->getChildrenByTagName( '*' );
  my %arg = map { $_->nodeName, $_->textContent } @nodes;
  my $task = App::Toodledo::Task->new;

  # Protect against extra attributes being added before we can update
  my %attr_map = map { $_, 1 } $task->_actual_attributes;
  defined( $arg{$_} ) and $task->$_( _datemod( $_, $arg{$_} ) )
    for grep { $attr_map{$_} } keys %arg;
  $task;
}


sub get_folders
{
  my $self = shift;

  my $context = $self->call_func( 'getFolders' );
  my @folders;
  for my $element ($context->findnodes( 'folders/folder' ))
  {
    my $folder = App::Toodledo::Folder->new;
    $folder->name( $element->textContent );
    $folder->$_( $element->getAttribute( $_  ) )
      for qw(id private archived order);
    push @folders, $folder;
  }
  sort { $a->order <=> $b->order } @folders;
}


# Incoming date/datetimes get converted from strings to epoch times internally
sub _datemod
{
  my ($what, $value) = @_;

  return $value
    unless $what =~ /\A(?:added|modified|startdate|duedate|completed)\Z/;

  $value = str2time $value;
  $value || '';
}


sub _make_key
{
  my $self = shift;

  my $context = $self->call_func( 'getToken' );
  $self->_key_from_context( $context );
}


sub _single_token
{
  my ($self, $token, $context) = @_;

  my ($element) = $context->findnodes( $token );
  $element->textContent;
}


sub _key_from_context
{
  my ($self, $context) = @_;

  my $token = $self->_single_token( token => $context );
  md5_hex( md5_hex( $self->password ) . $token . $self->userid );
}


sub _make_client   # Overrideable for testing
{
  my $self = shift;

  REST::Client->new( host => shift );
}


method call_func => positional (
  { isa => 'Str', required => 1 },
  { isa => 'HashRef', default => {} } ) => sub
{
  my ($self, $func, $argref) = @_;

  my $client = $self->client or croak "Must login first";
  _debug( "Calling function $func\n" );
  $client->GET( $self->_make_path( $func, %$argref ) );
  $client->responseCode != 200 and croak "Unable to contact Toodledo\n";
  $client->responseContent =~ /(Excessive API token requests.*blocked)/s
    and croak "$1\n";
  my $doc = $client->responseXpath;
  _context_from_doc( $doc );
};


# Somehow the behavior changed with REST::Client v134
sub _context_from_doc
{
  #  my $doc = shift;

  my $context = shift;   # XML::LibXML::XPathContext->new( $doc );
  my ($error) = $context->findnodes( 'error' );
  croak "API error: " . $error->textContent if $error;
  $context;
}


sub _make_path
{
  my $self = shift;
  my $func = shift;
  my %rest = @_;

  my $path = "/api.php?method=$func;";
  $path .= $self->key ? "key=" . $self->key : "userid=" . $self->userid;
  $path .= ";$_=" . _mung_attr( $_, $rest{$_} ) for keys %rest;
  _debug( "path = $path\n" );
  $path;
}


sub _mung_attr
{
  my ($attr, $value) = @_;

  if ( $attr =~ /\A(?:title|tag)\Z/ )
  {
    return _toodledo_encode( $value );
  }
  if ( $attr =~ /\A(?:(start|mod|comp)?(?:before|after))\Z/ )
  {
    my $type = $1 || '';
    return $type eq 'mod' ? _toodledo_time( $value ) : _toodledo_date( $value );
  }
  $value;
}


sub _toodledo_encode
{
  local $_ = shift;

  s/&/%26/g;
  s/;/%3B/g;
  $_;
}


sub _toodledo_time
{
  my $time = shift;

  strftime( "%Y-%m-%d %T", localtime $time);
}

sub _toodledo_date
{
  my $time = shift;

  strftime( "%Y-%m-%d", localtime $time);
}


method add_task => positional (
  { isa => 'App::Toodledo::Task', required => 1 } ) => sub
{
  my ($self, $task) = @_;

  $self->_add_a( task => $task->_for_api );
};


sub add_folder
{
  my ($self, $whatever, $private) = @_;

  $whatever or croak "Must supply folder object or title";
  my $title;
  if (ref $whatever)
  {
    my $folder = $whatever;
    ($title, $private) = ($folder->name, $folder->private);
  }
  else
  {
    $title = $whatever;
  }
  my %opt = (title => $title);
  $opt{private} = $private if defined $private;
  $self->_add_a( folder => \%opt );
}


sub add_context
{
  my ($self, $title) = @_;

  $title or croak "Must supply title";
  $self->_add_a( context => { title => $title } );
}


sub add_goal
{
  my ($self, $title, $level, $contrib) = @_;

  $title or croak "Must supply title";
  my %opt = (title => $title);
  $opt{level} = $level if defined $level;
  $opt{contributes} = $contrib if defined $contrib;
  $self->_add_a( goal => \%opt );
}


sub _add_a
{
  my ($self, $what, $argref) = @_;

  _debug( "Adding a $what\n" );
  $self->_call_single( "add\L\u$what", added => $argref );
}


sub _call_single
{
  my ($self, $func, $token, $argref) = @_;

  my $context = $self->call_func( $func, $argref );
  $self->_single_token( $token => $context );
}


sub delete_task
{
  my $self = shift;
  $self->_delete_a( task => shift );
}


sub delete_goal
{
  my $self = shift;
  $self->_delete_a( goal => shift );
}


sub delete_folder
{
  my $self = shift;
  $self->_delete_a( folder => shift );
}

sub delete_context
{
  my $self = shift;
  $self->_delete_a( context => shift );
}


method _delete_a => positional (
  { isa => 'Str', required => 1 },
  { isa => 'Int', required => 1 } ) => sub
{
  my ($self, $what, $id) = @_;

  _debug( "Deleting a $what\n" );
  $self->_call_single( "delete\L\u$what", success => { id => $id } );
};


sub _debug
{
  print STDERR @_ if $ENV{APP_TOODLEDO_DEBUG};
}

1;

__END__

=head1 NAME

App::Toodledo - Interacting with the Toodledo task management service.

=head1 SYNOPSIS

    use App::Toodledo;

    my $todo = App::Toodledo->new();
    $todo->login_from_rc;
    my %search_opts = ( notcomp => 1, before => time );  # Already expired
    $todo->foreach_task( \&per_task, \%search_opts );

    sub per_task {
        my ($self, $task) = @_;
        print $task->title, ": due on " . localtime( $task->duedate );
    }

=head1 DESCRIPTION

Toodledo (L<http://www.toodledo.com/>) is a web-based capability for managing
to-do lists along Getting Things Done (GTD) lines.  This module
provides a Perl-based access to its API.

What do you need the API for?  Doesn't the web interface do everything
you want?  Not always.  See the examples included with this distribution.
For instance, Toodledo has only one level of notification and it's either
on or off.  With the API you can customize the heck out of notification.

This is a very basic, preliminary Toodledo module.  I wrote it to do the
few things I wanted out of an API and when I feel a need for some
additional capability, I'll add it.  In the mean time, if there's something
you want it to do, feel free to submit a patch.  Or, heck, if you're
sufficiently motivated, I'll let you take over the whole thing.

=head1 METHODS

=head2 $todo = App::Toodledo->new;

Construct a new Toodledo handle.  This call does not contact the
service.

=head2 $todo->login( $userid, $password )

"Login" to Toodledo. The userid is the long string on your Toodledo
account's "Settings" page.

=head2 $todo->login_from_rc

Same as C<login>, only obtains the userid and password from a YAML
file in your home directory called C<.toodledorc>.  The attributes
C<userid> and C<password> must be set, like this:

  ---
  userid: td94d4b473d171f
  password: secret

=head2 $todo->call_func( $function, $argref )

Call an arbitrary Toodledo API function C<$function>.  Use this for any
function not wrapped in a more convenient method below.  Arguments
are supplied via a hashref.  Examples:

  $context = $todo->call_func( 'getAccountInfo'  );
  $context = $todo->call_func( getUserid => { email => $email, pass => $pass })

The result is an L<XML::LibXML::Element>.  See the CPAN documentation
for that class and its superclass, L<XML::LibXML::Node>.  The
C<findnodes> and C<getChildrenByTagName> methods are particularly useful.

=head2 $todo->foreach_task( \&callback, [ \%search_opts ] )

Run the subroutine C<callback> for every task that matches the
search criteria in C<%search_opts>.  The callback will be called with
two arguments: the C<$todo> object and a L<App::Toodledo::Task> object.
The search options are as described in the Toodledo API documentation
for the C<getTasks> call, with the following modifications:

=over 4

=item *

The C<title> and C<tag> arguments will be encoded for you;

=item *

The C<before>, C<after>, C<startbefore>, C<modbefore>, C<compbefore>,
C<startafter>, C<modafter>, and C<compafter> arguments should be
integer epoch times such as returned by C<time>.  They will be
converted to the required format for you.

=back

=head2 @folders = $todo->get_folders

Return a list of L<App::Toodledo::Folder> objects, ordered by their
C<order> attribute.

=head2 $id = $todo->add_task( $task )

The argument should be a new L<App::Toodledo::Task> object to be created.
The result is the id of the new task.

=head2 $id = $todo->add_context( $title )

Add a context with the given title.

=head2 $id = $todo->add_folder( $title_or_folder, [ $private ] )

Add a folder with the given title.  C<$private> if supplied must be either
0 (default) or 1, which signifies that the folder is to be private.
If the first argument is an L<App::Toodledo::Folder> object, the title
and private attributes will be taken from it.

=head2 $id = $todo->add_goal( $title, [ $level, [ $contributes ] ] )

Add a goal with the given title.  The C<$level> if supplied should be
0 (default), 1, or 2, signifying goal span (0=lifetime, 1=long-term,
2=short-term).  If C<$contributes> is supplied, it should be the id of
a higher-level goal that this goal contributes to.

=head2 $success = $todo->delete_task( $id )

Delete the task with the given C<$id>.  The result is a boolean for the
success of the operation.

=head2 $success = $todo->delete_goal( $id )

Delete the goal with the given C<$id>.  The result is a boolean for the
success of the operation.

=head2 $success = $todo->delete_context( $id )

Delete the context  with the given C<$id>.  The result is a boolean for the
success of the operation.

=head2 $success = $todo->delete_folder( $id )

Delete the folder  with the given C<$id>.  The result is a boolean for the
success of the operation.

=head1 ERRORS

Any API call may croak if it returns an error.  A common cause of this
would be making too many API calls within an hour.  The limit seems to be
reached much faster than you would think based on Toodledo's claims for
what that limit is.  Just wait an hour if you hit this limit.

=head1 ENVIRONMENT

Setting the environment variable C<APP_TOODLEDO_DEBUG> will cause
debugging-type information to be output to STDERR.

=head1 AUTHOR

Peter J. Scott, C<< <cpan at psdt.com> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-app-toodledo at rt.cpan.org>, or through
the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-Toodledo>.
I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 TODO

Help improve App::Toodledo!  Some low-hanging fruit you might want to
submit a patch for:

=over 4

=item *

Use the new C<unix> parameter to C<getTasks> to simplify date fetching.

=item *

Implement the C<getContexts> call to an C<App::Toodledo::Context> object.

=item *

Ditto for goals.

=item *

Implement the C<editTask> and C<editFolder> calls.

=item *

Implement task caching to avoid hitting API limits.

=back

=head1 SUPPORT

You can find documentation for this module with the perldoc command:

    perldoc App::Toodledo

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Toodledo>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-Toodledo>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-Toodledo>

=item * Search CPAN

L<http://search.cpan.org/dist/App-Toodledo/>

=back

=head1 SEE ALSO

Toodledo API documentation: L<http://www.toodledo.com/info/api_doc.php>.

Getting Things Done, David Allen, ISBN 978-0142000281.

=head1 COPYRIGHT & LICENSE

Copyright 2009 Peter J. Scott, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
