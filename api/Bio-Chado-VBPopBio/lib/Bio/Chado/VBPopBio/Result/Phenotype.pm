package Bio::Chado::VBPopBio::Result::Phenotype;

use base 'Bio::Chado::Schema::Result::Phenotype::Phenotype';
__PACKAGE__->load_components('+Bio::Chado::VBPopBio::Util::Subclass');
__PACKAGE__->subclass({
		       nd_experiment_phenotypes => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentPhenotype',
		       assay => 'Bio::Chado::VBPopBio::Result::Cvterm',
		       attr => 'Bio::Chado::VBPopBio::Result::Cvterm',
		       observable => 'Bio::Chado::VBPopBio::Result::Cvterm',
		       cvalue => 'Bio::Chado::VBPopBio::Result::Cvterm',
		       phenotypeprops => 'Bio::Chado::VBPopBio::Result::Phenotypeprop',
		      });

use aliased 'Bio::Chado::VBPopBio::Util::Multiprops';

=head1 NAME

Bio::Chado::VBPopBio::Result::Phenotype

=head1 SYNOPSIS

Phenotype object with extra convenience functions

=head1 MANY-TO-MANY RELATIONSHIPSa

=head2 experiments

Type: many_to_many

Returns a list of experiments

Related object: Bio::Chado::VBPopBio::Result::Experiment

=cut

__PACKAGE__->many_to_many
    (
     'experiments',
     'nd_experiment_phenotypes' => 'nd_experiment',
    );

=head1 SUBROUTINES/METHODS

=head2 add_multiprop

Adds normal props to the object but in a way that they can be
retrieved in related semantic chunks or chains.  E.g.  'insecticide'
=> 'permethrin' => 'concentration' => 'mg/ml' => 150 where everything
in single quotes is an ontology term.  A multiprop is a chain of
cvterms optionally ending in a free text value.

This is more flexible than adding a cvalue column to all prop tables.

Usage: $experiment>add_multiprop($multiprop);

See also: Util::Multiprop (object) and Util::Multiprops (utility methods)

=cut

sub add_multiprop {
  my ($self, $multiprop) = @_;

  return Multiprops->add_multiprop
    ( multiprop => $multiprop,
      row => $self,
      prop_relation_name => 'phenotypeprops',
    );
}

=head2 multiprops

get a arrayref of multiprops

=cut

sub multiprops {
  my ($self) = @_;

  return Multiprops->get_multiprops
    ( row => $self,
      prop_relation_name => 'phenotypeprops',
    );
}

=head2 as_data_structure

returns a json-like hashref of arrayrefs and hashrefs

=cut

sub as_data_structure {
  my ($self, $seen) = @_;
  return {
	  name => $self->name,
	  uniquename => $self->uniquename,
	  observable => $self->observable->as_data_structure,
	  defined $self->attr ? (attribute => $self->attr->as_data_structure) : (),
	  value => {
		    text => $self->value,
		    term => defined $self->cvalue ? $self->cvalue->as_data_structure : undef,
		    unit => defined $self->assay ? $self->assay->as_data_structure : undef,
		   },
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

1; # End of Bio::Chado::VBPopBio::Result::Phenotype
