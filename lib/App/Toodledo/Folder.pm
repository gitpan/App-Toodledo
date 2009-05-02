package App::Toodledo::Folder;
use strict;
use warnings;

our $VERSION = '0.01';

use Carp;
use Moose;

has name        => ( is => 'rw', isa => 'Str' );
has private     => ( is => 'rw', isa => 'Int' );
has archived    => ( is => 'rw', isa => 'Int' );
has order       => ( is => 'rw', isa => 'Int' );

1;

__END__

=head1 NAME

App::Toodledo::Folder - class encapsulating a Toodledo folder

=head1 SYNOPSIS

  $folder = App::Toodledo::Folder->new;
  $folder->name( 'Shopping List' )
  $todo = App::Toodledo->new;
  $todo->add_folder( $folder );

=head1 DESCRIPTION

This class provides accessors for the properties of a Toodledo folder.
The following attributes are defined:

  name
  private
  archived
  order

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
