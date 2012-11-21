package Bio::Chado::VBPopBio::Result::Organism;

use base 'Bio::Chado::Schema::Result::Organism::Organism';
__PACKAGE__->load_components('+Bio::Chado::VBPopBio::Util::Subclass');
__PACKAGE__->subclass({
		       stocks => 'Bio::Chado::VBPopBio::Result::Stock',
#		       organismprops => 'Bio::Chado::VBPopBio::Result::Organismprop',
});
__PACKAGE__->resultset_attributes({ order_by => 'organism_id' });

=head1 NAME

Bio::Chado::VBPopBio::Result::Organism

=head1 SYNOPSIS

Organism object with extra convenience functions

=head1 SUBROUTINES/METHODS

=head2 name

Simply returns genus<space>species (or just genus if no species)

=cut

sub name {
  my $self = shift;
  return $self->species ? $self->genus.' '.$self->species : $self->genus;
}


=head2 as_data_structure

returns a json-like hashref of arrayrefs and hashrefs

=cut

sub as_data_structure {
  my ($self) = @_;
  return {
      id => $self->id,
      name => $self->name,
  };
}


=head1 AUTHOR

VectorBase, C<< <info at vectorbase.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 VectorBase.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Bio::Chado::VBPopBio::Result::Organism
