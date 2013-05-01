package Bio::Chado::VBPopBio::ResultSet::Stock;

use strict;
use base 'DBIx::Class::ResultSet';
use Carp;
use aliased 'Bio::Chado::VBPopBio::Util::Multiprops';


=head1 NAME

Bio::Chado::VBPopBio::ResultSet::Stock

=head1 SYNOPSIS

Stock resultset with extra convenience functions


=head1 SUBROUTINES/METHODS

=head2 find_or_create_from_isatab

 Usage: $stocks->find_or_create_from_isatab($isatab_sample_name, $isatab_sample_data, $project, $ontologies, $study);

 Desc: This method creates a stock object from the isatab sample hashref.
 Ret : a new Stock row
 Args: sample_name string
       hashref (example contents below)
         { description   => '...',
           material_type => 'whole_organism',
           characteristics => { Sex => { value => 'female', term_accession_number => 123, term_source_ref => 'ABC' } },
         }
       Project object
       hashref $isa->{ontology_lookup} from Bio::Parser::ISATab
       hashref current ISA study (maybe needed for protocols one day?)

=cut

sub find_or_create_from_isatab {
  my ($self, $sample_name, $sample_data, $project, $ontologies, $study) = @_;

  # my $stocknum = $self->count + 1;

  my $schema = $self->result_source->schema;

  # create a stock type cvterm (maybe this could be optionally overwritten)
  my $cvterms = $schema->cvterms;
  my $dbxrefs = $schema->dbxrefs;

  my $material_type = $cvterms->find_by_accession($sample_data->{material_type});

  croak "Sample material type not found (REF=$sample_data->{material_type}{term_source_ref},ACC=$sample_data->{material_type}{term_accession_number})\n" unless (defined $material_type);

  # first check to see if we have a sample stable ID that's already in the db
  if ($self->looks_like_stable_id($sample_name)) {
    my $existing_stock = $self->find_by_stable_id($sample_name);
    # will only work if sample_name is VBSnnnnnnn of course
    if (defined $existing_stock) {
      # now check some vital things are the same:
      if ($existing_stock->type_id == $material_type->cvterm_id) {
	if (keys %{$sample_data->{characteristics}}) {
	  $schema->defer_exception_once("Sample characteristics have been provided for pre-existing samples.  This is not allowed (as validating them would be onerous).");
	}
	return $existing_stock;
      } else {
	$schema->defer_exception("reused sample $sample_name, Material Type does not agree with existing sample");
      }
    } else {
      $schema->defer_exception("$sample_name looked like a stable ID but we couldn't find it in the database");
    }
  }

  # otherwise we create a new one
  my $stock = $self->create({
			     name => $sample_name,
			     uniquename => $study->{study_identifier}.":".$sample_name,
			     description => $sample_data->{description},
			     type => $material_type,
			    });

  # Create or re-use a "stable id"
  my $stable_id = $stock->stable_id($project);

  #
  # Deal with "Characteristics [term name (ONTO:accession)]" columns
  # by adding multiprops for them
  #
  Multiprops->add_multiprops_from_isatab_characteristics
    ( row => $stock,
      prop_relation_name => 'stockprops',
      characteristics => $sample_data->{characteristics} ) if ($sample_data->{characteristics});

  #
  # before adding comments, deal with the
  # "simple sample derivation" column "Comment [derived from]"
  #
  if (defined (my $progenitor_id = delete $sample_data->{comments}{"derived from"})) {
    # do nothing yet
    my $progenitor = $self->find_by_stable_id($progenitor_id);
    if (defined $progenitor) {
      my $manipulation = $schema->sample_manipulations->create();
      # fake an Assay Name so we can get a stable ID
      $manipulation->external_id("$sample_name derived from $progenitor_id");
      my $stable_id = $manipulation->stable_id($project);
      # link the stocks
      $manipulation->add_to_stocks($progenitor, { type => $schema->types->assay_uses_sample });
      $manipulation->add_to_stocks($stock, { type => $schema->types->assay_creates_sample });
      # link to projects
      $manipulation->add_to_projects($project);
      # but do we add the progenitor sample to the project?
      # on reflection, maybe not...
      # $progenitor->add_to_projects($project);
    } else {
      $schema->defer_exception("Can't find 'derived from' sample $progenitor_id for $sample_name");
    }
  }

  #
  # Deal with "Comments [a topic]" columns
  # by adding multiprops for them
  #
  Multiprops->add_multiprops_from_isatab_comments
    ( row => $stock,
      prop_relation_name => 'stockprops',
      comments => $sample_data->{comments} ) if ($sample_data->{comments});

  if ($sample_data->{factor_values}) {
    warn "Warning: Not currently loading factor values for samples\n" unless ($self->{FV_WARNED_ALREADY}++);
  }

  return $stock;
}

=head2 projects

convenience search for all related projects

=cut

sub projects {
  my ($self) = @_;
  my $link_type = $self->result_source->schema->types->project_stock_link;

  return $self->search_related('stock_projects',
			       {
				# no search terms
			       },
			       {
				bind => [ $link_type->id ],
			       }
			      )->search_related('project', { }, { distinct => 1 });
}

=head2 search_by_project

usage:
  $resultset = $stocks->search_by_project({ 'project.name' => { in => [ 'name1', 'name2' ] }});

Filters stocks based on a query of the projects attached via nd_experiment.
Does not join to projectprops.

=cut

sub search_by_project {
  my ($self, $query) = @_;

  warn "deprecated search_by_project - needs updating to use project_stock\n";

  croak "search_by_project argument must be a hash ref\n" unless (ref($query) eq 'HASH');

  return $self->search($query,
		       { join => { nd_experiment_stocks =>
				   { nd_experiment =>
				     { nd_experiment_projects => 'project' }}}});
}

=head2 search_by_nd_experimentprop

Usage:
  $resultset = $stocks->search_by_nd_experimentprop( { 'type.name' => 'start date',
                                                       'value' => { like => '2005%' } } );

=cut

sub search_by_nd_experimentprop {
  my ($self, $query) = @_;
  croak "search_by_nd_experimentprop argument must be a hash ref\n" unless (ref($query) eq 'HASH');
  return $self->search_by_nd_experimentprops(1,$query);
}

=head2 search_by_nd_experimentprops

Usage:
  $resultset = $stocks->search_by_nd_experimentprops(2,
                 { 'type.name' => 'start date',
                   'nd_experimentprops.value' => { like => '2005%' },
                   'type_2.name' => 'end date',
                   'nd_experimentprops_2.value' => { like => '2005%' },
                 });

Use this where you want an experiment that was performed straddling a particular date,
or perhaps on a date AND at a time.

First argument is the number of times we want to join to the props table
Second argument is the query - check the example above for the _2 _3 syntax - this
is because the underlying query is a multiple join to the same table(s).

=cut

sub search_by_nd_experimentprops {
  my ($self, $num, $query) = @_;
  return $self->search($query,
		       { join => { nd_experiment_stocks =>
				   { nd_experiment =>
				     [ ({nd_experimentprops => { type => { dbxref => 'db' }}}) x $num ] }}});
}

=head2 search_by_nd_geolocationprop

Usage:
  $resultset = $stocks->search_by_nd_geolocationprop( { 'type.name' => 'collection site country',
                                                        'value' => 'Mali' } );

=cut

sub search_by_nd_geolocationprop {
  my ($self, $query) = @_;

  croak "search_by_nd_geolocationprop argument must be a hash ref\n" unless (ref($query) eq 'HASH');

  return $self->search($query,
		       { join => { nd_experiment_stocks =>
				   { nd_experiment =>
				     { nd_geolocation =>
				       { nd_geolocationprops =>
					 { type => { dbxref => 'db' }}}}}}});
}


=head2 search_by_nd_protocolprop

Usage:
  $resultset = $stocks->search_by_nd_protocolprop( { 'type.name' => 'direct bioassay' } );

=cut

sub search_by_nd_protocolprop {
  my ($self, $query) = @_;

  croak "search_by_nd_protocolprop argument must be a hash ref\n" unless (ref($query) eq 'HASH');

  return $self->search_by_nd_protocolprops(1, $query);
# 		       { join => { nd_experiment_stocks =>
# 				   { nd_experiment =>
# 				     { nd_experiment_protocols =>
# 				       { nd_protocol =>
# 					 { nd_protocolprops =>
# 					   { type => { dbxref => 'db' }}}}}}}});
}

=head2 search_by_nd_protocolprops

Usage:
  $resultset = $stocks->search_by_nd_protocolprop(2,  { 'type.name' => 'direct bioassay', 'type_2.name' => 'concentration' } );

=cut

sub search_by_nd_protocolprops {
  my ($self, $num, $query) = @_;
  return $self->search($query,
		       { join => { nd_experiment_stocks =>
				   { nd_experiment =>
				     { nd_experiment_protocols =>
				       { nd_protocol =>
					 [ ({nd_protocolprops => { type => { dbxref => 'db' }}}) x $num ] }}}}});
}



=head2 search_by_phenotype

Usage:
  $resultset = $stocks->search_by_phenotype( { 'observable.name' => '% mortality' } );

=cut

sub search_by_phenotype {
  my ($self, $query) = @_;

  croak "search_by_phenotype argument must be a hash ref\n" unless (ref($query) eq 'HASH');

  return $self->search($query,
		       { join => { nd_experiment_stocks =>
				   { nd_experiment =>
				     { nd_experiment_phenotypes =>
				       { phenotype => [ qw/observable attr cvalue/ ] }}}}});
}


=head2 search_by_species_identification_assay_result

Usage:
  $resultset = $stocks->search_by_species_identification_assay_result( { 'type.name' => { like => 'Anopheles %' }} );

This won't work in combination with other nd_experimentprop searches.
It does work as $project->stocks->search_by_species_identification_assay_result().
It will need to be changed when we move to genotype + genotypeprop storage of these results.

=cut

sub search_by_species_identification_assay_result {
  my ($self, $query) = @_;
  croak "search_by_species_identification_assay_result argument must be a hash ref\n" unless (ref($query) eq 'HASH');
  return $self->search($query,
		       { join => { nd_experiment_stocks =>
				   { nd_experiment =>
				     [
				      { nd_experimentprops => 'type' },
							'type'
				     ] }}})->search({ 'type_2.name' => 'species identification assay' });
}

=head2 find_by_stable_id

Look up dbxref VBS entry and return stock if it has one

=cut

sub find_by_stable_id {
  my ($self, $stable_id) = @_;

  my $schema = $self->result_source->schema;
  my $db = $schema->dbs->find_or_create({ name => 'VBS' });

  my $search = $db->dbxrefs->search({ accession => $stable_id });

  if ($search->count == 1 && $search->first->stocks->count == 1) {
    return $search->first->stocks->first;
  }
  return undef;
}

=head2 looks_like_stable_id

check to see if VBS\d{7}

=cut

sub looks_like_stable_id {
  my ($self, $id) = @_;
  return $id =~ /^VBS\d{7}$/;
}


=head1 TO DO

Definitely need some more date-aware search functions.

May need to use SQL literal queries to call server-side SQL date conversion functions
so that we can use less/greater than range queries.


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
