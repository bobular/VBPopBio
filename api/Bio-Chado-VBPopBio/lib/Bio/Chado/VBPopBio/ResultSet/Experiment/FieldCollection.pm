package Bio::Chado::VBPopBio::ResultSet::Experiment::FieldCollection;

use base 'Bio::Chado::VBPopBio::ResultSet::Experiment';
use Carp;
use strict;

=head1 NAME

Bio::Chado::VBPopBio::ResultSet::Experiment::FieldCollection

=head1 SYNOPSIS

FieldCollection resultset with extra convenience functions

    my $fcs = $schema->field_collections()->search_on_something_location_related_xxx(...);

=head1 SUBROUTINES/METHODS

=head2 new

overloaded constructor adds default resultset filtering on field collection type_id

=cut

sub new {
  my ($class, $source, $attribs) = @_;
  $attribs = {} unless $attribs;
  $attribs->{where}{type_id} = $source->schema->types->field_collection->cvterm_id;
  return $class->SUPER::new($source, $attribs);
}

=head2 create_from_isatab

 Usage: $field_collections->create_from_isatab($assay_name, $isatab_assay_data, $project, $stock, $ontologies, $study);

 Desc: This method creates a FieldCollection nd_experiment object from the isatab assay sample hashref
       (from a field collection assay)
 Ret : a new Experiment::FieldCollection row (is a NdExperiment)
 Args: hashref $isa->{studies}[N]{study_assay_lookup}{'field collection'}{samples}{SAMPLE_ID}
       (example contents below)
         {
           characteristics => { 'Collection site' => { value => 'Kela',
                                                       term_accession_number => 123,
                                                       term_source_ref => 'GAZ' } },
         }
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
  my $field_collection = $self->find_and_link_existing($assay_name, $project);

  unless (defined $field_collection) {

    # create the nd_experiment and stock linker type
    my $schema = $self->result_source->schema;

    # potentially re-use a geolocation
    # the following call deletes any location-specific characteristics from $assay_data
    my $geolocation = $schema->geolocations->find_or_create_from_isatab($assay_data);

    # always create a new nd_experiment object
    $field_collection = $self->create({ nd_geolocation => $geolocation });
    $field_collection->external_id($assay_name);
    my $stable_id = $field_collection->stable_id($project);

    # add description, characteristics etc
    $field_collection->annotate_from_isatab($assay_data);

    # link it to the project
    $field_collection->add_to_projects($project);

    # add the protocols
    $field_collection->add_to_protocols_from_isatab($assay_data->{protocols}, $ontologies, $study);
  }

  $field_collection->relink($saved_links) if ($saved_links);

  return $field_collection;
}


=head2 _type

private method to return type cvterm for this subclass

=cut

sub _type {
  my ($self) = @_;
  return $self->result_source->schema->types->field_collection;
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
