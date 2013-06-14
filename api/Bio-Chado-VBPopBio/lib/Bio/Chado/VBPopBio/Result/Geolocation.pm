package Bio::Chado::VBPopBio::Result::Geolocation;

use feature 'switch';
use base 'Bio::Chado::Schema::Result::NaturalDiversity::NdGeolocation';
__PACKAGE__->load_components(qw/+Bio::Chado::VBPopBio::Util::Subclass/);
__PACKAGE__->subclass({
		       nd_experiments => 'Bio::Chado::VBPopBio::Result::Experiment',
		       nd_geolocationprops => 'Bio::Chado::VBPopBio::Result::Geolocationprop',
		      });

use aliased 'Bio::Chado::VBPopBio::Util::Multiprops';

=head1 NAME

Bio::Chado::VBPopBio::Result::Experiment

=head1 SYNOPSIS

Geolocation object with extra convenience functions.

=head1 SUBROUTINES/METHODS


=head2 summary

returns a brief HTML summary of the loacations

=cut

sub summary {
  my ($self) = @_;
  my $schema = $self->result_source->schema;

  my $collection_site_term = $schema->types->collection_site;
  my ($gazprop) = $self->multiprops($collection_site_term);
  if ($gazprop) {
    return $gazprop->cvterms->[1]->name;
  } else {
    # return a concatenated list of all free-text multiprops:
    return join "; ", map $_->value, grep $_->value, $self->multiprops;
  }
}

=head2 add_multiprop

Adds normal props to the object but in a way that they can be
retrieved in related semantic chunks or chains.  E.g.  'insecticide'
=> 'permethrin' => 'concentration' => 'mg/ml' => 150 where everything
in single quotes is an ontology term.  A multiprop is a chain of
cvterms optionally ending in a free text value.

This is more flexible than adding a cvalue column to all prop tables.

Usage: $location->add_multiprop($multiprop);

See also: Util::Multiprop (object) and Util::Multiprops (utility methods)

=cut

sub add_multiprop {
  my ($self, $multiprop) = @_;

  return Multiprops->add_multiprop
    ( multiprop => $multiprop,
      row => $self,
      prop_relation_name => 'nd_geolocationprops',
    );
}

=head2 multiprops

return an array of multiprops
optional filter cvterm (identity matching)

=cut

sub multiprops {
  my ($self, $filter) = @_;

  return Multiprops->get_multiprops
    ( row => $self,
      prop_relation_name => 'nd_geolocationprops',
      filter => $filter,
    );
}

=head2 as_data_structure

returns a json-like hashref of arrayrefs and hashrefs

=cut

sub as_data_structure {
  my ($self) = @_;
  return {
	  longitude => $self->longitude,
	  latitude => $self->latitude,
	  geodetic_datum => $self->geodetic_datum,
	  altitude => $self->altitude,
	  name => $self->description,
	  props => [ map { $_->as_data_structure } $self->multiprops ],
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

1;
