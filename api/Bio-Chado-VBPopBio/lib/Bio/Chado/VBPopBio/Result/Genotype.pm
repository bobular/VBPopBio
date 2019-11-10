package Bio::Chado::VBPopBio::Result::Genotype;

use base 'Bio::Chado::Schema::Result::Genetic::Genotype';
__PACKAGE__->load_components('+Bio::Chado::VBPopBio::Util::Subclass');
__PACKAGE__->subclass({
		       nd_experiment_genotypes => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentGenotype',
		       genotypeprops => 'Bio::Chado::VBPopBio::Result::Genotypeprop',
		       type => 'Bio::Chado::VBPopBio::Result::Cvterm',
		      });

use aliased 'Bio::Chado::VBPopBio::Util::Multiprops';
use Bio::Chado::VBPopBio::Util::Functions qw/ordered_hashref/;

=head1 NAME

Bio::Chado::VBPopBio::Result::Genotype

=head1 SYNOPSIS

Genotype object with extra convenience functions

=head1 MANY-TO-MANY RELATIONSHIPS

=head2 experiments

Type: many_to_many

Returns a list of experiments

Related object: Bio::Chado::VBPopBio::Result::Experiment

=cut

__PACKAGE__->many_to_many
    (
     'experiments',
     'nd_experiment_genotypes' => 'nd_experiment',
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
      prop_relation_name => 'genotypeprops',
    );
}

=head2 multiprops

get a arrayref of multiprops

=cut

sub multiprops {
  my ($self, $filter) = @_;

  return Multiprops->get_multiprops
    ( row => $self,
      prop_relation_name => 'genotypeprops',
      filter => $filter,
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
	  description => $self->description,
	  props => [ map { $_->as_data_structure } $self->multiprops ],
	  type => $self->type->as_data_structure,
	 };
}


=head2 as_isatab

=cut

sub as_isatab {
  my ($self, $study) = @_;

  my $isa = ordered_hashref;
  $isa->{description} = $self->description;
  my $type = $self->type;
  my $type_dbxref = $type->dbxref;
  $isa->{type}{value} = $type->name;
  $isa->{type}{term_source_ref} = $type_dbxref->db->name;
  $isa->{type}{term_accession_number} = $type_dbxref->accession;
  ($isa->{comments}, $isa->{characteristics}) = Multiprops->to_isatab($self);

  # there is some cut and paste duplication with Phenotype.pm here which
  # could probably be fixed by making Genotype and Phenotype inherit from
  # a new class "AssayResult"

  # fake a protocol to go from Assay to Phenotype
  my $protocol_key = 'DOCUMENTING';
  my $protocol_isa = $isa->{protocols}{$protocol_key} = {};

  # also add to investigation sheet if needed
  my $already_added_to_investigation_sheet =
    grep { $_->{study_protocol_name} eq $protocol_key }
      @{$study->{study_protocols}};
  unless ($already_added_to_investigation_sheet) {
    push @{$study->{study_protocols}},
	{
	 study_protocol_name => $protocol_key,
	 study_protocol_type => 'documenting',
	 study_protocol_type_term_source_ref => 'OBI',
	 study_protocol_type_term_accession_number => 'IAO_0000572',
	 # study_protocol_description => '',
	};
  }


  return $isa;
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

1; # End of Bio::Chado::VBPopBio::Result::Genotype
