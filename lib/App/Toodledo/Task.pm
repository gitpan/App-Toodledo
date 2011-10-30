package App::Toodledo::Task;
use strict;
use warnings;

our $VERSION = '1.00';

use Carp;
use Moose;
use MooseX::Method::Signatures;
use App::Toodledo::TaskInternal;
use App::Toodledo::Util qw(toodledo_decode toodledo_encode);

use Moose::Util::TypeConstraints;
BEGIN { class_type 'App::Toodledo' };

extends 'App::Toodledo::InternalWrapper';

# TODO: Figure out how to put this attribute in the wrapper:
has object => ( is => 'ro', isa => 'App::Toodledo::TaskInternal',
	        default => sub { App::Toodledo::TaskInternal->new },
	        handles => sub { __PACKAGE__->internal_attributes( $_[1] ) } );

method tag ( @args ) {
  toodledo_decode( $self->object->tag( @args ) );
}

method title ( @args ) {
  toodledo_decode( $self->object->title( @args ) );
}

method note ( @args ) {
  toodledo_decode( $self->object->note( @args ) );
}


method tags {
  split /,/, $self->tag;
}


# Return id of added task
method add ( App::Toodledo $todo! ) {
  my %param = %{ $self->object };
  $param{$_} = toodledo_encode( $param{$_} )
    for grep { $param{$_} } qw(title tag note);
  my $added_ref = $todo->call_func( tasks => add => { tasks => \%param } );
  $added_ref->[0]{id};
}


method optional_attributes ( $class: ) {
  my @attrs = $class->attribute_list;
  grep { ! /\A(?:id|title|modified|completed)\z/ } @attrs;
}


method edit ( App::Toodledo $todo! ) {
  my %param = %{ $self->object };
  my $edited_ref = $todo->call_func( tasks => edit => { tasks => \%param } );
  $edited_ref->[0]{id};
}


method delete ( App::Toodledo $todo! ) {
  my $id = $self->id;
  my $deleted_ref = $todo->call_func( tasks => delete => { tasks => [$id] } );
  $deleted_ref->[0]{id} == $id or croak "Did not get ID back from delete";
}


1;

__END__

=head1 NAME

App::Toodledo::Task - class encapsulating a Toodledo task

=head1 SYNOPSIS

  $task = App::Toodledo::Task->new;
  $task->title( 'Put the cat out' );

=head1 DESCRIPTION

This class provides accessors for the properties of a Toodledo task.
The attributes of a task are defined in the L<App::Toodledo::TaskRole>
module.

=head1 METHODS

=head2 tags


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

Copyright 2009-2011 Peter J. Scott, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
