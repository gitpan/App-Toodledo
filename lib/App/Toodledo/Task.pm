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

my %ENUM_STRING = ( status => {
		     0 => 'None',
		     1 => 'Next Action',
		     2 => 'Active',
		     3 => 'Planning',
		     4 => 'Delegated',
		     5 => 'Waiting',
		     6 => 'Hold',
		     7 => 'Postponed',
		     8 => 'Someday',
		     9 => 'Canceled',
		     10 => 'Reference',
		    },
		    priority => {
		       -1 => 'Negative',
		       0  => 'Low',
		       1  => 'Medium',
		       2  => 'High',
		       3  => 'Top',
		    }
		  );
my %ENUM_INDEX = (
		  status   => { reverse %{ $ENUM_STRING{status}   } },
		  priority => { reverse %{ $ENUM_STRING{priority} } },
		 );

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


method status_str ( Item $new_status? ) {
  $self->set_enum( status => $new_status );
}

method priority_str ( Item $new_priority? ) {
  $self->set_enum( priority => $new_priority );
}

method set_enum ( Str $type!, Item $new_value? ) {
  my @args;
  if ( $new_value )
  {
    defined( my $index = $ENUM_INDEX{$type}{$new_value} )
      or croak "\u$type $new_value not valid";
    push @args, $index;
  }
  my $index = $self->object->$type( @args );
  my $string = $ENUM_STRING{$type}{$index}
    or croak "Toodledo returned invalid $type index $index";
  $string;
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

=head2 @tags = $task->tags

Return the tags of the task as a list (splits the attribute on comma).

=head2 $task->status_str, $task->priority_str

Each of these methods operates on the string defined at
http://api.toodledo.com/2/tasks/index.php, not the integer.
The string will be turned into the integer going into Toodledo
and the integer will get turned into the string coming out.
Examples:

  $task->priority_str( 'Top' )
  $task->status_str eq 'Hold' and ...

Each method can be used in a App::Toodledo::select call.

=head1 CAVEAT

This is a very basic implementation of Toodledo tasks.  It is missing
much that would be helpful with dealing with repeating tasks.  Patches
welcome.

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
