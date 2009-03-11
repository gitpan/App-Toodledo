package App::Toodledo::Task;
use strict;
use warnings;

our $VERSION = '0.01';

use Carp;
use Moose;
use MooseX::Method;

# NOTE: If you add any attribute that is not a Toodledo property,
# you must come up with a way to replace the line commented ****
# below.  It uses the shortcut of listing all the possible
# attributes of the class in order to see what should be passed
# to the Toodledo task creation call.  Maybe naming internal
# attributes with a leading underscore and putting the appropriate
# grep in the **** line would be a good approach.

has id           => ( is => 'rw', isa => 'Int' );
has parent       => ( is => 'rw', isa => 'Int' );
has children     => ( is => 'rw', isa => 'Int' );
has title        => ( is => 'rw', isa => 'Str' );
has tag          => ( is => 'rw', isa => 'Str' );
has folder       => ( is => 'rw', isa => 'Int' );
has context      => ( is => 'rw', isa => 'Str' );
has goal         => ( is => 'rw', isa => 'Str' );
has added        => ( is => 'rw', isa => 'Str' );
has modified     => ( is => 'rw', isa => 'Str' );
has startdate    => ( is => 'rw', isa => 'Str' );
has duedate      => ( is => 'rw', isa => 'Str' );
has duetime      => ( is => 'rw', isa => 'Str' );
has completed    => ( is => 'rw', isa => 'Str' );
has repeat       => ( is => 'rw', isa => 'Int' );
has rep_advanced => ( is => 'rw', isa => 'Str' );
has status       => ( is => 'rw', isa => 'Int' );
has star         => ( is => 'rw', isa => 'Int' );
has priority     => ( is => 'rw', isa => 'Int' );
has length       => ( is => 'rw', isa => 'Int' );
has timer        => ( is => 'rw', isa => 'Int' );
has note         => ( is => 'rw', isa => 'Str' );

sub _for_api
{
  my $self = shift;

  my %attr;
  $self->title or croak "Title required";
  my $attr_map = $self->meta->get_attribute_map;    # ****
  for my $attr (keys %$attr_map)
  {
    defined(my $value = $self->$attr) or next;
    $value = _mung_attr( $attr, $value );
    $attr{$attr} = $value;
  }

  \%attr;
}


sub _mung_attr
{
  my ($attr, $value) = @_;

  if ( $attr =~ /\A(?:title|tag)\Z/ )
  {
    return App::Toodledo::_toodledo_encode( $value );
  }
  if ( $attr =~ /\A(?:added|startdate|duedate|modified|completed)\Z/ )
  {
    my $type = $1 || '';
    return $type eq 'modified' ? App::Toodledo::_toodledo_time( $value )
                               : App::Toodledo::_toodledo_date( $value );
  }
  $value;
}


1;

__END__

=head1 NAME

App::Toodledo::Task - class encapsulating a Toodledo task

=head1 SYNOPSIS

  $task = App::Toodledo::Task->new;
  $task->title( 'Put the cat out' );
  $todo = App::Toodledo->new;
  $todo->login_from_rc;
  $todo->add_task( $task );

=head1 DESCRIPTION

This class provides accessors for the properties of a Toodledo task.
The following accessors are defined:

 id           
 parent       
 children     
 title        
 tag          
 folder       
 context      
 goal         
 added        
 modified     
 startdate    
 duedate      
 duetime      
 completed    
 repeat       
 rep_advanced 
 status       
 star         
 priority     
 length       
 timer        
 note         

=head2 Variant behaviors

The return value for the following accessors:

=over

=item *

added

=item *

modified

=item *

startdate

=item *

duedate

=item *

completed

=back

is not the Toodledo textual date but instead a Unix
epoch time (integer seconds) like that returned by C<time()>.  Likewise,
when supplying a value to these accessors, supply an epoch time.
The object will convert the values coming and going to Toodledo.

=head1 CAVEAT

This is a very basic implementation of Toodledo tasks.  It only
represents the contents of elements and does not capture the
attributes of the few elements in Toodledo tasks that can have them.
This is likely to have the most ramifications for programs working
on repeating tasks.

=head1 AUTHOR

Peter J. Scott, C<< <cpan at psdt.com> >>

=head1 SEE ALSO

Toodledo: L<http://www.toodledo.com/>.

Toodledo API documentation: L<http://www.toodledo.com/info/api_doc.php>.

=head1 COPYRIGHT & LICENSE

Copyright 2009 Peter J. Scott, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
