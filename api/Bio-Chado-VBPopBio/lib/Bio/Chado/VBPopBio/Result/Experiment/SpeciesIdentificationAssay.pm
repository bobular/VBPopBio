package Bio::Chado::VBPopBio::Result::Experiment::SpeciesIdentificationAssay;

use strict;
use base 'Bio::Chado::VBPopBio::Result::Experiment';
__PACKAGE__->load_components(qw/+Bio::Chado::VBPopBio::Util::Subclass/);
__PACKAGE__->subclass({ }); # must call this routine even if not setting up relationships.

=head1 NAME

Bio::Chado::VBPopBio::Result::Experiment::SpeciesIdentificationAssay

=head1 SYNOPSIS

Species identification assay


=head1 SUBROUTINES/METHODS

=head result_summary

returns a brief HTML summary of the assay results

=cut

sub result_summary {
  my ($self) = @_;
  my $best_species = $self->best_species;

  if ($best_species) {
    my $method = 'unknown method';
    my @protocols = $self->protocols->all;
    if (@protocols) {
      $method = join ', ', map { $_->type->name } @protocols;
    }
    return '<span class="species_name">'.$best_species->name."</span> ($method)";
  } elsif ($self->search_related('nd_experimentprops', { 'type_id' => $self->result_source->schema->types->deprecated->id })->next) {
    return 'deprecated data';
  } else {
    return 'no data';
  }
}


=head2 best_species

NOTE: Mostly copied from Stock::best_species()

interrogates results of this assay and returns the most "detailed" species ontology term

returns undefined if nothing suitable found

Will return undefined if this assay is tagged as deprecated.

In list context returns ($species_term, @qualification_terms) where the
latter is a list of (one) internal term (maybe later formalised into VBcv) to
describe how the result was arrived at

At present, the most leafward unambiguous term is returned.

e.g. if identified as Anopheles arabiensis AND Anopheles gambiae s.s. then Anopheles gambiae s.l. would be returned (with no further qualifying information at present).

The algorithm does not care if terms are from different ontologies but
probably should, as there may be no common ancestor terms.

Curators should definitely restrict within-project species terms to
the same ontology.

=cut

sub best_species {
  my ($self) = @_;
  my $schema = $self->result_source->schema;

  my $sar = $schema->types->species_assay_result;

  my $result;
  my $qualification = $schema->types->unambiguous;
  my $internal_result; # are we returning a non-leaf node?
  my $deprecated_term = $schema->types->deprecated;

  # don't process results from this assay if it's deprecated
  unless ($self->search_related('nd_experimentprops', { 'type_id' => $deprecated_term->id })->next) {
    foreach my $result_multiprop ($self->multiprops($sar)) {
      my $species_term = $result_multiprop->cvterms->[-1]; # second/last term in chain
      if (!defined $result) {
	$result = $species_term;
      } elsif ($result->has_child($species_term)) {
	# return the leaf-wards term unless we already chose an internal node
	$result = $species_term unless ($internal_result);
      } elsif ($species_term->id == $result->id || $species_term->has_child($result)) {
	# that's fine - stick with the leaf term
      } else {
	# we need to return a common 'ancestral' internal node
	foreach my $parent ($species_term->recursive_parents_same_ontology) {
	  if ($parent->has_child($result)) {
	    $result = $parent;
	    $internal_result = 1;
	    $qualification = $schema->types->ambiguous;
	    last;
	  }
	}
      }
    }
  }
  $qualification = $schema->types->unknown unless $result;
  return wantarray ? ($result, $qualification) : $result;
}


=head2 annotate_from_isatab

  Usage: $assay->annotate_from_isatab($assay_data)

  Return value: none

  Args: hashref of ISA-Tab data: $study->{study_assays}[0]{samples}{SAMPLE_NAME}{assays}{ASSAY_NAME}

Adds description, comments, characteristics to the assay/nd_experiment object

Specialised version which asks the cvterm lookup to look up VBsp terms
via secondary cvterm_dbxref linker before looking via primary dbxref
(see ResultSet::Cvterm->find_by_accession for more explanation)

=cut

sub annotate_from_isatab {
  my ($self, $assay_data) = @_;

  # add an extra key/value to tell cvterm loader to get the VBsp term for
  # values in the species assay result column
  # grep for the characteristics column name(s)
  # then add the data
  map { $assay_data->{characteristics}{$_}{prefered_term_source_ref} = 'VBsp' }
    grep { /VBcv:0000961|species assay result/ } keys %{$assay_data->{characteristics}};

  $self->SUPER::annotate_from_isatab($assay_data);
}

=head2 as_data_structure

nothing special added here yet.

=cut

sub as_data_structure {
  my ($self, $depth) = @_;

  return {
	  $self->basic_info,
	  type => 'species identification assay',
	 };
}

=head2 as_cytoscape_graph

returns a perl data structure corresponding to Cytoscape JSON format

=cut

sub as_cytoscape_graph {
  my ($self, $nodes, $edges) = @_;

  $nodes //= {};
  $edges //= {};

  my $assay_id = sprintf "assay%08d", $self->id;
  $nodes->{$assay_id} //= { data => {
				     id => $assay_id,
				     name => $self->external_id,
				     type => $self->type->name,
				    } };

  my ($best_species, $qualification) = $self->best_species;
  if (defined $best_species) {
    my $species_id = "$assay_id.species";
    $nodes->{$species_id} //= { data => {
					 id => $species_id,
					 name => $best_species->name,
					 qualifier => $qualification->name,
					 type => 'species',
					} };
    $edges->{"$assay_id:$species_id"} //= { data => {
						    id => "$assay_id:$species_id",
						    source => $assay_id,
						    target => $species_id,
						   } };
  }

  my $graph = {
	       elements => {
			    nodes => [ values(%$nodes) ],
			    edges => [ values(%$edges) ],
			   }
	      };

  return $graph;
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
