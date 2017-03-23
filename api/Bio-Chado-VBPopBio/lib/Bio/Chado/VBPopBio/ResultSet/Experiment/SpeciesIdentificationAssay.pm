package Bio::Chado::VBPopBio::ResultSet::Experiment::SpeciesIdentificationAssay;

use strict;
use base 'Bio::Chado::VBPopBio::ResultSet::Experiment';
use Carp;

=head1 NAME

Bio::Chado::VBPopBio::ResultSet::Experiment::SpeciesIdentificationAssay

=head1 SYNOPSIS

SpeciesIdentificationAssay resultset with extra convenience functions

=head1 SUBROUTINES/METHODS

=head2 new

overloaded constructor adds default resultset filtering on species identification assay type_id

=cut

sub new {
  my ($class, $source, $attribs) = @_;
  $attribs = {} unless $attribs;
  $attribs->{where}{type_id} = $source->schema->types->species_identification_assay->cvterm_id;
  return $class->SUPER::new($source, $attribs);
}

=head2 create_from_isatab

 Usage: $species_identification_assays->create_from_isatab($assay_name, $isatab_assay_data, $project, $stock, $ontologies, $study);

 Desc: This method creates a stock object from the isatab assay sample hashref
 Ret : a new Experiment::SpeciesIdentificationAssay row (is a NdExperiment)
 Args: hashref $isa->{studies}[N]{study_assay_lookup}{'species identification assay'}{samples}{SAMPLE_NAME}{assays}{ASSAY_NAME}
       Project object (Bio::Chado::VBPopBio)
       hashref $isa->{ontology_lookup} from ISA-Tab returned from Bio::Parser::ISATab
       hashref ISA-Tab current study (used for protocols)

=cut

sub create_from_isatab {
  my ($self, $assay_name, $assay_data, $project, $stock, $ontologies, $study) = @_;

  # maybe the assay is in use by another project so wasn't deleted
  # but we still need to delete it and relink it afterwards
  my $saved_links = $self->find_and_delete_existing($assay_name, $project, $stock);
  # maybe $assay_name is a stable ID and we just need to "borrow" an assay from an existing project
  my $species_identification_assay = $self->find_and_link_existing($assay_name, $project);

  unless (defined $species_identification_assay) {
    # create the nd_experiment and stock linker type
    my $schema = $self->result_source->schema;
    my $cvterms = $schema->cvterms;

    # always create a new nd_experiment object
    $species_identification_assay = $self->create();
    $species_identification_assay->external_id($assay_name);
    my $stable_id = $species_identification_assay->stable_id($project);

    # add description, characteristics etc (INCLUDING THE 'species assay result's)
    $species_identification_assay->annotate_from_isatab($assay_data);

    # add it to the project
    $species_identification_assay->add_to_projects($project);

    $species_identification_assay->add_to_protocols_from_isatab($assay_data->{protocols}, $ontologies, $study, $stable_id);
  }

  $species_identification_assay->relink($saved_links) if ($saved_links);

  return $species_identification_assay;
}


=head2 _type

private method to return type cvterm for this subclass

=cut

sub _type {
  my ($self) = @_;
  return $self->result_source->schema->types->species_identification_assay;
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
