package Bio::Chado::VBPopBio::Result::Stock;

use strict;
use base 'Bio::Chado::Schema::Result::Stock::Stock';
__PACKAGE__->load_components('+Bio::Chado::VBPopBio::Util::Subclass');
__PACKAGE__->resultset_class('Bio::Chado::VBPopBio::ResultSet::Stock'); # required because BCS has a custom resultset
__PACKAGE__->subclass({
		       nd_experiment_stocks => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentStock',
		       stockprops => 'Bio::Chado::VBPopBio::Result::Stockprop',
		       organism => 'Bio::Chado::VBPopBio::Result::Organism',
		       type => 'Bio::Chado::VBPopBio::Result::Cvterm',
		      });
#__PACKAGE__->resultset_attributes({ order_by => 'stock_id' });

use aliased 'Bio::Chado::VBPopBio::Util::Multiprops';
use Carp;
use POSIX;
use Bio::Chado::VBPopBio::Util::Functions qw/ordered_hashref/;

=head1 NAME

Bio::Chado::VBPopBio::Result::Stock

=head1 SYNOPSIS

Stock object with extra convenience functions

    $stock = $schema->stocks->find({uniquename => 'Anopheles subpictus Sri Lanka 2003-1'});
    $experiments = $stock->experiments();

=head1 RELATIONSHIPS

=head2 stock_projects

related virtual object/table: Bio::Chado::VBPopBio::Result::Linker::StockProject

see also methods add_to_projects and projects

=cut

__PACKAGE__->has_many(
  "stock_projects",
  "Bio::Chado::VBPopBio::Result::Linker::StockProject",
  { "foreign.stock_id" => "self.stock_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);



=head1 MANY-TO-MANY RELATIONSHIPS

=head2 nd_experiments

Type: many_to_many

Returns a list of experiments

Related object: L<Bio::Chado::Schema::Result::NaturalDiversity::NdExperiment>

=cut

__PACKAGE__->many_to_many
    (
     'nd_experiments',
     'nd_experiment_stocks' => 'nd_experiment',
    );

=head2 dbxrefs

Type: many_to_many

Returns a list of dbxrefs

Related object: L<Bio::Chado::Schema::Result::General::Dbxref>

=cut

__PACKAGE__->many_to_many
    (
     'dbxrefs',
     'stock_dbxrefs' => 'dbxref',
    );



=head1 SUBROUTINES/METHODS

=head2 experiments

Returns all experiments related to this stock.


=cut

sub experiments {
  my ($self) = @_;
  return $self->nd_experiments();
  # or $self->search_related('nd_experiment_stocks')->search_related('nd_experiment');
}

=head2 field_collections

Get all field_collections (based on nd_experiment.type)

=cut

sub field_collections {
  my ($self) = @_;
  return $self->experiments_by_type($self->result_source->schema->types->field_collection);
}

=head2 phenotype_assays

Get all phenotype assays (based on nd_experiment.type)

=cut

sub phenotype_assays {
  my ($self) = @_;
  return $self->experiments_by_type($self->result_source->schema->types->phenotype_assay);
}

=head2 genotype_assays

Get all genotype assays (based on nd_experiment.type)

=cut

sub genotype_assays {
  my ($self) = @_;
  return $self->experiments_by_type($self->result_source->schema->types->genotype_assay);
}

=head2 species_identification_assays

Get all species ID assays (based on nd_experiment.type)

=cut

sub species_identification_assays {
  my ($self) = @_;
  return $self->experiments_by_type($self->result_source->schema->types->species_identification_assay);
}

=head2 sample_manipulations

Get all sample manipulation events (based on nd_experiment.type)

=cut

sub sample_manipulations {
  my ($self) = @_;
  return $self->experiments_by_type($self->result_source->schema->types->sample_manipulation);
}


=head2 experiments_by_type

Helper method not intended for general use.
See field_collections, phenotype_assays for usage.

=cut

sub experiments_by_type {
  my ($self, $type) = @_;
  return $self->experiments->search({ 'nd_experiment.type_id' => $type->cvterm_id })->ordered_by_id;
}

=head2 experiments_by_link_type

Argument should most likely be one of

  $assay_creates_stock = $types->assay_creates_sample;
  $assay_uses_stock = $types->assay_uses_sample;

=cut

sub experiments_by_link_type {
  my ($self, $type) = @_;
  return $self->search_related('nd_experiment_stocks', { 'me.type_id' => $type->id })->search_related('nd_experiment');
}

=head2 add_to_projects

there is no project_stocks relationship in Chado so we have a nasty
hack using stockprops and projectprops with a special type and a negative rank

returns the stockprop

=cut


sub add_to_projects {
  my ($self, $project) = @_;
  my $schema = $self->result_source->schema;
  my $link_type = $schema->types->project_stock_link;

  my $projectprop = $schema->resultset('Projectprop')->find_or_create(
				       { project_id => $project->id,
					 type => $link_type,
					 value => undef,
					 rank => -$self->id
				       } );

  return $self->find_or_create_related('stockprops',
				       { type => $link_type,
					 value => undef,
					 rank => -$project->id
				       } );

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
			      )->search_related('project');
}

=head2 external_id

alias for stock.name, because that's where we store it.

=cut

sub external_id {
  my $self = shift;
  return $self->name;
}

=head2 stable_id

usage 1: $stock->stable_id($project); # when attempting to find an existing id or make a new one
usage 2: $stock->stable_id(); # all other times

If a $stock->dbxref is present then the dbxref->accession is returned.
If not, and if a $project argument has been provided then a new dbxref will be determined
by looking for an existing dbxref with props 'project external ID' => $project->external_id
and 'sample external ID' => $stock->external_id (which should remain after a sample
has been deleted) or failing that, creating a new VBS0123456 style ID.

=cut

my $VBS_db; # crudely cached

sub stable_id {
  my ($self, $project) = @_;

  if (defined $self->dbxref_id and my $dbxref = $self->dbxref) {
    if ($dbxref->db->name ne 'VBS') {
      croak "fatal error: stock.dbxref is not from db.name='VBS'\n";
    }
    return $dbxref->accession;
  }
  unless ($project) {
    croak "fatal error: stock->stable_id called on dbxref-less stock without project arg\n";
  }

  my $schema = $self->result_source->schema;

  $VBS_db //= $schema->dbs->find_or_create({ name => 'VBS' });
  my $proj_extID_type = $schema->types->project_external_ID;
  my $samp_extID_type = $schema->types->sample_external_ID;

  my $search = $VBS_db->dbxrefs->search
    ({
      'dbxrefprops.type_id' => $proj_extID_type->id,
      'dbxrefprops.value' => $project->external_id,
      'dbxrefprops_2.type_id' => $samp_extID_type->id,
      'dbxrefprops_2.value' => $self->external_id,
     },
     { join => [ 'dbxrefprops', 'dbxrefprops' ] }
    );

  my $count = $search->count;
  if ($count == 0) {
    # need to make a new ID

    # first, find the "highest" accession in dbxref for VBP
    my $last_dbxref_search = $schema->dbxrefs->search
      ({ db_id => $VBS_db->id },
       { order_by => { -desc => 'accession' },
         rows => 1 });

    my $next_number = 1;
    if ($last_dbxref_search->count) {
      my $acc = $last_dbxref_search->first->accession;
      my ($prefix, $number) = $acc =~ /(\D+)(\d+)/;
      $next_number = $number+1;
    }

    # now create the dbxref
    my $new_dbxref = $schema->dbxrefs->create
      ({
	db => $VBS_db,
	accession => sprintf("VBS%07d", $next_number),
	dbxrefprops => [ {
			 type => $proj_extID_type,
			 value => $project->external_id,
			 rank => 0,
			},
		        {
			 type => $samp_extID_type,
			 value => $self->external_id,
			 rank => 0,
			},
		       ]
       });
    # set the stock.dbxref to the new dbxref
    $self->dbxref($new_dbxref);
    $self->update; # make it permanent
    return $new_dbxref->accession; # $self->stable_id would be nice but slower
  } elsif ($count == 1) {
    # set the stock.dbxref to the stored stable id dbxref
    my $old_dbxref = $search->first;
    $self->dbxref($old_dbxref);
    $self->update; # make it permanent
    return $old_dbxref->accession;
  } else {
    croak "Too many VBS dbxrefs for project ".$project->external_id." + sample ".$self->external_id."\n";
  }

}



=head2 add_multiprop

Adds normal props to the object but in a way that they can be
retrieved in related semantic chunks or chains.  E.g.  'insecticide'
=> 'permethrin' => 'concentration' => 'mg/ml' => 150 where everything
in single quotes is an ontology term.  A multiprop is a chain of
cvterms optionally ending in a free text value.

This is more flexible than adding a cvalue column to all prop tables.

Usage:  $stock->add_multiprop($multiprop);

See also: Util::Multiprop (object) and Util::Multiprops (utility methods)

=cut

sub add_multiprop {
  my ($self, $multiprop) = @_;

  return Multiprops->add_multiprop
    ( multiprop => $multiprop,
      row => $self,
      prop_relation_name => 'stockprops',
    );
}

=head2 delete_multiprop

Usage: my $success = $stock->delete_multiprop($multiprop)

returns true (the multiprop object) if an exact copy of the multiprop is found and deleted,
or false (undef) otherwise

=cut

sub delete_multiprop {
  my ($self, $multiprop) = @_;

  return Multiprops->delete_multiprop
    ( multiprop => $multiprop,
      row => $self,
      prop_relation_name => 'stockprops',
    );
}



=head2 multiprops

return an array of multiprops

=cut

sub multiprops {
  my ($self, $filter) = @_;

  return Multiprops->get_multiprops
    ( row => $self,
      prop_relation_name => 'stockprops',
      filter => $filter,
    );
}



=head2 as_data_structure

returns a json-like hashref of arrayrefs and hashrefs

=cut

sub as_data_structure {
  my ($self, $depth, $project) = @_;
  $depth = INT_MAX unless (defined $depth);

  my ($best_species, @species_qualifications) = $self->best_species($project);

  return {
      id => $self->stable_id, # use stable_id when ready
      name => $self->name,
      description => $self->description,

      # we try to reduce redundancy by just having name (it's identical to external_id anyway)
      # external_id => $self->external_id,

      # make sure 'recursion' won't go too deep using $depth argument
      # however, no depth checks for some contained objects, such as species, cvterms etc
      type => $self->type->as_data_structure,

      species => defined $best_species ? $best_species->as_data_structure : undef,
      species_qualifications => [ map $_->as_data_structure, @species_qualifications ],

      props => [ map { $_->as_data_structure } $self->multiprops ],

	  # the sorting on ID below keeps assays in order, even if 'parent'
	  # projects have been loaded/deleted/reloaded
      ($depth > 0) ? (
		      field_collections => [ sort { $a->{id} cmp $b->{id} }
					     map { $_->as_data_structure($depth) }
					     $self->field_collections->filter_on_project($project) ],
		      species_identification_assays => [ sort { $a->{id} cmp $b->{id} }
							 map { $_->as_data_structure($depth) }
							 $self->species_identification_assays->filter_on_project($project) ],
		      genotype_assays => [ sort { $a->{id} cmp $b->{id} }
					   map { $_->as_data_structure($depth) }
					   $self->genotype_assays->filter_on_project($project) ],
		      phenotype_assays => [ sort { $a->{id} cmp $b->{id} }
					    map { $_->as_data_structure($depth) }
					    $self->phenotype_assays->filter_on_project($project) ],
		      sample_manipulations => [ sort { $a->{id} cmp $b->{id} }
						map { $_->as_data_structure($depth) }
						$self->sample_manipulations->filter_on_project($project) ]
		     )
	  : (),


	 };
}

=head2 as_isatab

generates isatab datastructure for writing to files with Bio::Parser::ISATab

=cut

sub as_isatab {
  my ($self, $study, $sample_id, $project_id) = @_;
  my $isa = { };

  my $material_type = $self->type;
  my $mt_dbxref = $material_type->dbxref;
  $isa->{material_type}{value} = $material_type->name;
  $isa->{material_type}{term_source_ref} = $mt_dbxref->db->name;
  $isa->{material_type}{term_accession_number} = $mt_dbxref->accession;

  my $sample_key; # needed for attaching assays below

  if ($sample_id && $project_id) { # passed as args when re-using a sample from another project
    $sample_key = $sample_id;
  } else {
    # this sample belongs to the project being dumped and needs all the columns
    $isa->{description} = $self->description;
    ($isa->{comments}, $isa->{characteristics}) = Multiprops->to_isatab($self);
    $sample_key = $self->name;
  }

  my $sample_manipulations = $self->sample_manipulations;
  my $manipulation = $sample_manipulations->first;
  if ($sample_manipulations->next) {
    my $schema = $self->result_source->schema;
    $schema->defer_exception("Wasn't expecting multiple sample_manipulations for $sample_key - perhaps its 'derived from' other samples in other projects that should be deleted first before dumping this one");
  }
  if ($manipulation) {
    my $sample_used = $manipulation->stocks_used->first;
    my $sample_created = $manipulation->stocks_created->first;

    if ($sample_created->id == $self->id) {
      $isa->{comments}{'derived from'} = $sample_used->stable_id;
    } elsif ($sample_used->id == $self->id) {
      my $schema = $self->result_source->schema;
      my $other_project_id = $sample_created->projects->first->stable_id;
      $schema->defer_exception("$sample_key is used by a 'derived from' sample manipulation from another project $other_project_id. You must dump and delete that project first before dumping and deleting this one.");
    } else {
      my $schema = $self->result_source->schema;
      schema->defer_exception("unexpected sample manipulation situation for $sample_key");
    }
  }

  foreach my $assay ($self->nd_experiments->ordered_by_id) {
    next unless ($assay->has_isatab_sheet);

    # don't dump the assay if it doesn't primarily belong to this project
    next if (defined $project_id && $assay->projects->first->stable_id ne $project_id);

    my $study_assay_measurement_type = $assay->isatab_measurement_type;

    # every assay with a different protocol (or combination of protocols) will
    # be put in a different study_assay
    my $protocols_fingerprint = join ' ', $study_assay_measurement_type, sort map { my ($a,$b)=split /:/,$_->name; $b; } $assay->protocols;
    $protocols_fingerprint =~ s/\W+/_/g;
    $protocols_fingerprint =~ s/_$//;

    my $num_existing_assays = @{$study->{study_assays} // []};
    my $assay_filename = "a_$protocols_fingerprint.txt";
    my $isa_assay_root =
      $study->{study_assay_fingerprint_lookup}{$protocols_fingerprint} //=
	$study->{study_assays}[$num_existing_assays] =
	  {
	   study_assay_measurement_type => $study_assay_measurement_type,
	   study_assay_measurement_type_term_source_ref => $assay->type->dbxref->db->name,
	   study_assay_measurement_type_term_accession_number => $assay->type->dbxref->accession,
	   study_assay_file_name => $assay_filename,
	   samples => ordered_hashref(),
           comments => { dataset_names => 'VB-PopBio-test|1.0' },
	  };

    my $assay_name = $assay->external_id;
    $isa_assay_root->{samples}{$sample_key}{assays} //= ordered_hashref();
    $isa_assay_root->{samples}{$sample_key}{assays}{$assay_name} = $assay->as_isatab($study, $assay_filename);

#    my $study_assay_file_name = '???';
#    $study->{study_assay_lookup}{$assay_type} //= 123;
  }


  return $isa;
}


=head2 best_species

interrogates species_identification assays and returns the most "detailed" species ontology term

if optional project argument is provided, then only
species_identification_assays from that project will be used.

returns undefined if nothing suitable found

In list context returns ($species_term, @qualification_terms) where the
latter is a list of internal terms (maybe later formalised into VBcv) to
describe how the result was arrived at.  For example the results could be 'derived', 'unambiguous'

At present, the most leafward unambiguous term is returned.

e.g. if identified as Anopheles arabiensis AND Anopheles gambiae s.s. then Anopheles gambiae s.l. would be returned (with no further qualifying information at present).

The algorithm does not care if terms are from different ontologies but
probably should, as there may be no common ancestor terms.

Curators should definitely restrict within-project species terms to
the same ontology (fixed as of Mon Jun  3 and new VBsp ontology from Pantelis).

If there are zero species_identification_assays and there is a link to
another stock via a sample_manipulation - then take the best_species
of that stock.  Initially we will enforce the condition that the
sample_manipulation assay should have no protocols (indicating the
simple "Comment [derived from]" usage) and exactly one "stocks_used".
The best_species for the derived sample will come from all species
assays done on that sample (from any project).

=cut

sub best_species {
  my ($self, $project) = @_;
  my $schema = $self->result_source->schema;

  my $sar = $schema->types->species_assay_result;
  my $deprecated_term = $schema->types->deprecated;

  my $result;
  my $qualification = $schema->types->unambiguous;
  my $internal_result; # are we returning a non-leaf node?
  my @sp_id_assays = $self->species_identification_assays->filter_on_project($project)->all;
  foreach my $assay (@sp_id_assays) {

    # don't process results from this assay if it's deprecated
    unless ($assay->search_related('nd_experimentprops', { 'type_id' => $deprecated_term->id })->next) {

      foreach my $result_multiprop ($assay->multiprops($sar)) {
	my $species_term = $result_multiprop->cvterms->[-1]; # second/last term in chain
	if (!defined $result) {
	  $result = $species_term;
	} elsif ($result->has_child($species_term)) {
	  # return the leaf-wards term unless we already chose an internal node
	  $result = $species_term unless ($internal_result);
	} elsif ($species_term->id == $result->id  || $species_term->has_child($result)) {
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
  }
  my @qualifications = ($qualification);
  if (@sp_id_assays == 0) {
    my $sample_manips = $self->sample_manipulations;
    if (my $first_manip = $sample_manips->next) {
      if (!$sample_manips->next) {
	# there was only one manipulation
	# it has no protocols
	if ($first_manip->protocols->count == 0) {
	  my $used_stocks = $first_manip->stocks_used;
	  if (my $first_stock = $used_stocks->next) {
	    if (!$used_stocks->next) {
	      # only one stock used by the simple manip
	      my ($derived_result, $derived_qualification) = $first_stock->best_species;
	      $result = $derived_result;
	      @qualifications = ($schema->types->derived, $derived_qualification);
	    }
	  }
	}
      }
    }
  }
  # handle project fallback only if necessary
  unless (defined $result) {

    # if the project wasn't passed as an argument
    # we'll use the project belonging to this sample
    # ONLY if it is the only project belonging to it
    unless (defined $project) {
      my $projects = $self->projects;
      $project = $projects->next;
      $project = undef if ($projects->next); # this avoids two SELECTs on the db.
    }

    if (defined $project) {
      my $accession = $project->fallback_species_accession;
      if (defined $accession && $accession =~ /^(\w+):(\d+)$/) {
	my $fallback_term = $schema->cvterms->find_by_accession({ term_source_ref => $1,
								  term_accession_number => $2 });
	if ($fallback_term) {
	  $result = $fallback_term;
	  @qualifications = ($schema->types->project_default);
	}
      }
    }
  }

  @qualifications = ($schema->types->unknown) unless $result;
  return wantarray ? ($result, @qualifications) : $result;
}

=head2 relink

Links a stock back to objects passed in the hashref

=cut

sub relink {
  my ($self, $links) = @_;

  if ($links->{projects}) {
    foreach my $project (@{$links->{projects}}) {
      $self->add_to_projects($project);
    }
  }
  if ($links->{assays}) {
    # warn sprintf "%d and %d assays and links\n", scalar(@{$links->{assays}}), scalar(@{$links->{assay_link_type_ids}});
    foreach my $assay (@{$links->{assays}}) {
      my $link_type_id = shift @{$links->{assay_link_type_ids}};
      # warn "relinking ".$self->stable_id." to ".$assay->stable_id." type $link_type_id\n";
      $self->add_to_nd_experiments($assay, { type_id => $link_type_id });
    }
  }
}

=head2 as_cytoscape_graph

returns a perl data structure corresponding to Cytoscape JSON format

=cut

sub as_cytoscape_graph {
  my ($self, $nodes, $edges) = @_;

  $nodes //= {};
  $edges //= {};

  my $schema = $self->result_source->schema;
  my $types = $schema->types;

  my $assay_creates_stock = $types->assay_creates_sample;
  my $assay_uses_stock = $types->assay_uses_sample;

  my $sample_id = sprintf "sample%08d", $self->id;
  $nodes->{$sample_id} //= { data => {
				      id => $sample_id,
				      name => $self->name,
				      type => 'sample',
				     } };

  foreach my $link_type ($assay_creates_stock, $assay_uses_stock) {
    foreach my $assay ($self->experiments_by_link_type($link_type)) {
      my $assay_id = sprintf "assay%08d", $assay->id;
      $nodes->{$assay_id} //= { data => {
					 id => $assay_id,
					 name => $assay->external_id,
					 type => $assay->type->name,
					} };
      $edges->{"$sample_id:$assay_id"} //= { data => {
						      id => "$sample_id:$assay_id",
						      $link_type->id == $assay_uses_stock->id ?
						      (source => $sample_id,
						       target => $assay_id) :
						      (source => $assay_id,
						       target => $sample_id)
						     } };

      my $not_used = $assay->as_cytoscape_graph($nodes, $edges);
    }
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

1; # End of Bio::Chado::VBPopBio::Result::Stock
