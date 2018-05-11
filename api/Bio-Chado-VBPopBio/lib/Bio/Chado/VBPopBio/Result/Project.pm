package Bio::Chado::VBPopBio::Result::Project;

use strict;
use warnings;
use Carp;
use POSIX;

use feature 'switch';
use base 'Bio::Chado::Schema::Result::Project::Project';
__PACKAGE__->load_components(qw/+Bio::Chado::VBPopBio::Util::Subclass/);
__PACKAGE__->subclass({
		       nd_experiment_projects => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentProject',
		       projectprops => 'Bio::Chado::VBPopBio::Result::Projectprop',
                       project_pubs => 'Bio::Chado::VBPopBio::Result::Linker::ProjectPublication',
                       project_contacts => 'Bio::Chado::VBPopBio::Result::Linker::ProjectContact',
		       project_relationship_subject_projects => 'Bio::Chado::VBPopBio::Result::Linker::ProjectRelationship',
		       project_relationship_object_projects => 'Bio::Chado::VBPopBio::Result::Linker::ProjectRelationship',
		      });
#__PACKAGE__->resultset_attributes({ order_by => 'project_id' });

use aliased 'Bio::Chado::VBPopBio::Util::Multiprops';
use aliased 'Bio::Chado::VBPopBio::Util::Extra';
use aliased 'Bio::Chado::VBPopBio::Util::Date';
use Bio::Chado::VBPopBio::Util::Functions qw/ordered_hashref/;

=head1 NAME

Bio::Chado::VBPopBio::Result::Project

=head1 SYNOPSIS

Project object with extra convenience functions.
Specialised project classes will soon be found in the.
Bio::Chado::VBPopBio::Result::Project::* namespace.


=head1 RELATIONSHIPS

=head2 project_stocks

related virtual object/table: Bio::Chado::VBPopBio::Result::Linker::ProjectStock

see also methods add_to_stocks and stocks

=cut

__PACKAGE__->has_many(
  "project_stocks",
  "Bio::Chado::VBPopBio::Result::Linker::ProjectStock",
  { "foreign.project_id" => "self.project_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head1 MANY-TO-MANY RELATIONSHIPS

=head2 nd_experiments

Type: many_to_many

Returns a resultset of nd_experiments

Related object: Bio::Chado::Schema::NaturalDiversity::NdExperiment

=cut

__PACKAGE__->many_to_many
    (
     'nd_experiments',
     'nd_experiment_projects' => 'nd_experiment',
    );

=head2 publications

Type: many_to_many

Returns a resultset of publications

=cut

__PACKAGE__->many_to_many
    (
     'publications',
     'project_pubs' => 'pub',
    );

=head2 contacts

Type: many_to_many

Returns a resultset of contacts

=cut

__PACKAGE__->many_to_many
    (
     'contacts',
     'project_contacts' => 'contact',
    );


=head1 SUBROUTINES/METHODS

=head2 experiments

Get all experiments for this project.  Alias for nd_experiments (many to many relationship)

=cut

sub experiments {
  my ($self) = @_;
  return $self->nd_experiments(); # search_related('nd_experiment_projects')->search_related('nd_experiment');
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

Get all species identification assays (based on nd_experiment.type)

=cut

sub species_identification_assays {
  my ($self) = @_;
  return $self->experiments_by_type($self->result_source->schema->types->species_identification_assay);
}

=head2 experiments_by_type

arg: $cvterm

returns a resultset filtered on type

=cut

sub experiments_by_type {
  my ($self, $type) = @_;
  return $self->experiments->search({ type_id => $type->cvterm_id });
}

#  =head2 assays
#  
#  This is an alias for experiments()
#  
#  =cut
#  
#  sub assays {
#    my ($self) = @_;
#    return $self->experiments();
#  }

=head2 external_id

get/setter for the project external id (study identifier from ISA-Tab)
format 2011-MacCallum-permethrin-selected

returns undef if not found

(Can't use Util::Extra->attribute because we need the check that prevents the external ID changing.)

=cut

sub external_id {
  my ($self, $external_id) = @_;
  my $schema = $self->result_source->schema;
  my $proj_extID_type = $schema->types->project_external_ID;

  my $props = $self->search_related('projectprops',
				    { type_id => $proj_extID_type->id } );

  my $count = $props->count;
  if ($count > 1) {
    croak "project has too many external ids\n";
  } elsif ($count == 1) {
    my $retval = $props->first->value;
    croak "attempted to set a new external id ($external_id) for project with existing id ($retval)\n" if (defined $external_id && $external_id ne $retval);

    return $retval;
  } else {
    if (defined $external_id) {
      # no existing external id so create one
      # create the prop and return the external id
      $self->find_or_create_related('projectprops',
				    {
				     type => $proj_extID_type,
				     value => $external_id,
				     rank => 0
				    }
				   );
      return $external_id;
    } else {
      return undef;
    }
  }
  return undef;
}

=head2 stable_id

no args

Returns a dbxref from the VBP (VB Population Project) db
by looking up dbxrefprop "project external ID"

It will create a new entry with the next available accession if there is none.

The dbxref cannot be attached directly to the project (because there's no suitable
relationship in Chado).

=cut

sub stable_id {
  my ($self) = @_;

  my $dbxref = $self->_stable_id_dbxref();
  if (defined $dbxref) {
    return $dbxref->accession;
  }
}

# private method

sub _stable_id_dbxref {
  my ($self) = @_;
  my $schema = $self->result_source->schema;

  my $db = $schema->dbs->find_or_create({ name => 'VBP' });

  my $proj_extID_type = $schema->types->project_external_ID;

  my $search = $db->dbxrefs->search
    ({
      'dbxrefprops.type_id' => $proj_extID_type->id,
      'dbxrefprops.value' => $self->external_id,
     },
     { join => 'dbxrefprops' }
    );

  my $count = $search->count;
  if ($count == 0) {
    # need to make a new ID

    # first, find the "highest" accession in dbxref for VBP
    my $last_dbxref_search = $schema->dbxrefs->search
      ({ db_id => $db->id },
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
	db => $db,
	accession => sprintf("VBP%07d", $next_number),
	dbxrefprops => [ {
			 type => $proj_extID_type,
			 value => $self->external_id,
			 rank => 0,
			} ]
       });

    return $new_dbxref;
  } elsif ($count == 1) {
    return $search->first;
  } else {
    croak "Too many dbxrefs for project ".$self->external_id." with dbxrefprop project external ID";
  }
  return undef;
}

=head2 vis_configs

Get/setter for visualisation config JSON text.
Outer element should be an array.

=cut

sub vis_configs {
  my ($self, $json) = @_;
  return Extra->attribute
    ( value => $json,
      prop_type => $self->result_source->schema->types->vis_configs,
      prop_relation_name => 'projectprops',
      row => $self,
    );
}


=head2 submission_date

Get/setter for the submission date
(date is stored in a multiprop in Chado).

If no date is stored, return undef.

=cut

sub submission_date {
  my ($self, $date) = @_;
  my $valid_date = Date->simple_validate_date($date, $self);
  return Extra->attribute
    ( value => $valid_date,
      prop_type => $self->result_source->schema->types->submission_date,
      prop_relation_name => 'projectprops',
      row => $self,
    );
}

=head2 public_release_date

Get/setter for the submission date
(date is stored in a multiprop in Chado).

If no date is stored, return undef.

=cut

sub public_release_date {
  my ($self, $date) = @_;
  my $valid_date = Date->simple_validate_date($date, $self);
  return Extra->attribute
    ( value => $valid_date,
      prop_type => $self->result_source->schema->types->public_release_date,
      prop_relation_name => 'projectprops',
      row => $self,
    );
}

=head2 creation_date

get method only (but has side effects, see below)

can only be called on a project with a valid stable id

the creation date is stored as a dbxrefprop on the VBP dbxref

if this doesn't exist, it will be generated with today's date

=cut

sub creation_date {
  my ($self) = @_;

  my $stable_id_dbxref = $self->_stable_id_dbxref();

  if (defined $stable_id_dbxref) {
    my $schema = $self->result_source->schema;
    my $creation_date_type = $schema->types->creation_date;

    my $search = $stable_id_dbxref->search_related('dbxrefprops',
						   {
						    type_id => $creation_date_type->id,
						    rank => 0,
						   });

    my $first = $search->next;
    if (defined $first) {
      if (!defined $search->next) {
	return $first->value; # no sanity testing!
      } else {
	croak "too many creation date dbxrefprops";
      }
    } else {
      # make a new creation date dbxrefprop
      my $date = strftime "%Y-%m-%d", localtime;
      $stable_id_dbxref->add_to_dbxrefprops( {
					      type => $creation_date_type,
					      value => $date,
					      rank => 0,
					     });
      return $date;
    }
  } else {
    croak "creation date called but not stable id dbxref could be found";
  }
}

=head2 update_creation_date

"touch" the timestamp on the project (stable id dbxrefprop)

This is needed only in rare cases when a project is loaded and deleted (to secure a VBP ID, for example).
When the project is loaded for real at a later date, we want to refresh the creation_date.
This will be done with a commandline argument to bin/load_project.pl

=cut

sub update_creation_date {
  my ($self) = @_;
  my $stable_id_dbxref = $self->_stable_id_dbxref();

  if (defined $stable_id_dbxref) {
    my $schema = $self->result_source->schema;
    my $creation_date_type = $schema->types->creation_date;
    my $date = strftime "%Y-%m-%d", localtime;

    my $search = $stable_id_dbxref->search_related('dbxrefprops',
						   {
						    type_id => $creation_date_type->id,
						    rank => 0,
						   });

    my $first = $search->next;
    if (defined $first) {
      if (!defined $search->next) {
	$first->update({ value => $date });
	return $date;
      } else {
	croak "too many creation date dbxrefprops";
      }
    } else {
      # make a brand new dbxrefprop
      # (could probably have been done all-in-one (update_or_insert?))
      $stable_id_dbxref->add_to_dbxrefprops( {
					      type => $creation_date_type,
					      value => $date,
					      rank => 0,
					     });
      return $date;
    }
  } else {
    croak "no stable_id dbxref for update_creation_date";
  }

}



=head2 last_modified_date

return the last modified date string

will croak if no time stamp in db

call update_modification_date() explicitly to update/create the time stamp

=cut

sub last_modified_date {
  my ($self) = @_;

  my $stable_id_dbxref = $self->_stable_id_dbxref();

  if (defined $stable_id_dbxref) {
    my $schema = $self->result_source->schema;
    my $last_modified_date_type = $schema->types->last_modified_date;

    my $search = $stable_id_dbxref->search_related('dbxrefprops',
						   {
						    type_id => $last_modified_date_type->id,
						    rank => 0,
						   });

    my $first = $search->next;
    if (defined $first) {
      if (!defined $search->next) {
	return $first->value; # no sanity testing!
      } else {
	croak "too many last modified date dbxrefprops";
      }
    } else {
      croak "no last_modified_date dbxrefprop for project stable id dbxref";
    }
  } else {
    croak "no stable_id dbxref for last_modified_date";
  }
}

=head2 update_modification_date

"touch" the timestamp on the project (stable id dbxrefprop)

=cut

sub update_modification_date {
  my ($self) = @_;
  my $stable_id_dbxref = $self->_stable_id_dbxref();

  if (defined $stable_id_dbxref) {
    my $schema = $self->result_source->schema;
    my $last_modified_date_type = $schema->types->last_modified_date;
    my $date = strftime "%Y-%m-%d", localtime;

    my $search = $stable_id_dbxref->search_related('dbxrefprops',
						   {
						    type_id => $last_modified_date_type->id,
						    rank => 0,
						   });

    my $first = $search->next;
    if (defined $first) {
      if (!defined $search->next) {
	$first->update({ value => $date });
	return $date;
      } else {
	croak "too many last modified date dbxrefprops";
      }
    } else {
      # make a brand new dbxrefprop
      # (could probably have been done all-in-one (update_or_insert?))
      $stable_id_dbxref->add_to_dbxrefprops( {
					      type => $last_modified_date_type,
					      value => $date,
					      rank => 0,
					     });
      return $date;
    }
  } else {
    croak "no stable_id dbxref for update_modification_date";
  }

}

=head2 fallback_species_accession

Get/setter for species that stock->best_species should fall back to instead of the string 'Unknown'

It's stored as a simple string, e.g. "VBsp:0003480" to keep the code here simple...
(but maybe more complex elsewhere... we will see...)

=cut

sub fallback_species_accession {
  my ($self, $species_term_accession) = @_;
  return Extra->attribute
    ( value => $species_term_accession,
      prop_type => $self->result_source->schema->types->fallback_species_accession,
      prop_relation_name => 'projectprops',
      row => $self,
    );
}


=head2 delete

Deletes the project in a cascade which deletes all would-be orphan related objects.

It does not delete any would-be-orphaned contacts or publications.  Hopefully that will be
OK.  If not we will have to check that the contacts (or publications) don't belong to
several different object types before deletion.

The deletion "path" is project->stocks (via our fake relatonship)
and project->assays


=cut

sub delete {
  my $self = shift;
  # warn "I am deleting project ".$self->stable_id."\n";
  my $schema = $self->result_source->schema;
  my $link_type = $schema->types->project_stock_link;
  # delete stocks
  foreach my $stock ($self->stocks) {
    # if the stock has only one project it must be this one so ok to delete
    if ($stock->projects->count == 1) {
      # warn "I am deleting stock ".$stock->stable_id."\n";
      # first delete the link from here to the stock
      $self->search_related('projectprops',
			    { type_id => $link_type->id,
			      rank => -$stock->id,
			    })->delete;
      # then delete the stock (and the stockprop links back to project)
      $stock->delete;
    }
  }

  my $linkers = $self->related_resultset('nd_experiment_projects');
  while (my $linker = $linkers->next) {
    # check that the experiment is only attached to one project (has to be this one)
    if ($linker->nd_experiment->projects->count == 1) {
      $linker->nd_experiment->delete;
    }
    $linker->delete;
  }

  # now do contacts (experiment-contacts will have been done already)
  $linkers = $self->related_resultset('project_contacts');
  while (my $linker = $linkers->next) {
    # check that the contact is only attached to one project (has to be this one)
    if ($linker->contact->projects->count == 1) {
      $linker->contact->delete;
    }
    $linker->delete;
  }
  $linkers = $self->related_resultset('project_pubs');
  while (my $linker = $linkers->next) {
    # check that the pub is only attached to one project (has to be this one)
    if ($linker->pub->projects->count == 1) {
      $linker->pub->delete;
    }
    $linker->delete;
  }


  return $self->SUPER::delete();
}


=head2 add_multiprop

Adds normal props to the object but in a way that they can be
retrieved in related semantic chunks or chains.  E.g.  'insecticide'
=> 'permethrin' => 'concentration' => 'mg/ml' => 150 where everything
in single quotes is an ontology term.  A multiprop is a chain of
cvterms optionally ending in a free text value.

This is more flexible than adding a cvalue column to all prop tables.

Usage: $project->add_multiprop($multiprop);

See also: Util::Multiprop (object) and Util::Multiprops (utility methods)

=cut

sub add_multiprop {
  my ($self, $multiprop) = @_;

  return Multiprops->add_multiprop
    ( multiprop => $multiprop,
      row => $self,
      prop_relation_name => 'projectprops',
    );
}

=head2 multiprops

get a arrayref of multiprops

=cut

sub multiprops {
  my ($self, $filter) = @_;

  return Multiprops->get_multiprops
    ( row => $self,
      prop_relation_name => 'projectprops',
      filter => $filter,
    );
}

#DEPRECATED DON'T THINK IT'S USED ANYWHERE
# =head2 multiprop
# 
# get a single multiprop with the specified cvterm at position one in chain.
# 
# usage: $multiprop = $project->multiprop($submission_date_cvterm);
# 
# =cut
# 
# sub multiprop {
#   my ($self, $cvterm) = @_;
# 
#   return Multiprops->get_multiprops
#     ( row => $self,
#       prop_relation_name => 'projectprops',
#       filter => $cvterm,
#     );
# }


=head2 add_to_stocks

there is no project_stocks relationship in Chado so we have a nasty
hack using projectprops AND stockprops with a special type and a negative rank

usage: $project->add_to_stocks($stock_object);

returns the projectprop

=cut

sub add_to_stocks {
  my ($self, $stock) = @_;
  my $schema = $self->result_source->schema;
  my $link_type = $schema->types->project_stock_link;

  # add the "reverse relationship" from stock to project first
  my $stockprop = $schema->resultset('Stockprop')->find_or_create(
				       { stock_id => $stock->id,
					 type => $link_type,
					 value => undef,
					 rank => -$self->id
				       } );

  return $self->find_or_create_related('projectprops',
				       { type => $link_type,
					 value => undef,
					 rank => -$stock->id
				       } );
}


=head2 stocks

returns the stocks linked to the project via add_to_stocks()

=cut

sub stocks {
  my ($self, $stock) = @_;
  my $link_type = $self->result_source->schema->types->project_stock_link;
  return $self->search_related('project_stocks',
			       {
				# no search terms
			       },
			       {
				bind => [ $link_type->id ],
			       }
			      )->search_related('stock');
}


=head2 add_to_experiments

wrapper for add_to_nd_experiments

usage $project->add_to_experiments($experiment_object);

see experiments()

=cut

sub add_to_experiments {
  my ($self, @args) = @_;
  return $self->add_to_nd_experiments(@args);
}


=head2 has_geodata

arguments: limit

returns true if one of the first $limit samples has a single geolocation with lat+long data

=cut

sub has_geodata {
  my ($self, $limit) = @_;
  $limit //= 50;

  my $samples = $self->stocks;
  while (my $sample = $samples->next) {
    foreach my $experiment ($sample->field_collections) {
      if ($sample->field_collections->count == 1) {
	my $geo = $experiment->nd_geolocation;
	if (defined $geo->latitude && defined $geo->longitude) {
	  return 1;
	}
      }
    }
    last if ($limit-- <= 0);
  }
  # we didn't find any coords
  return 0;
}

=head2 as_data_structure

returns a json-like hashref of arrayrefs and hashrefs

=cut

sub as_data_structure {
  my ($self, $depth) = @_;
  $depth = INT_MAX unless (defined $depth);
  return {
	  name => $self->name,
	  id => $self->stable_id,
	  external_id => $self->external_id,
	  description => $self->description,
	  submission_date => $self->submission_date,
	  public_release_date => $self->public_release_date,
	  creation_date => $self->creation_date,
	  last_modified_date => $self->last_modified_date,
	  vis_configs => $self->vis_configs,
	  publications => [ map { $_->as_data_structure } $self->publications ],
	  contacts => [ map { $_->as_data_structure } $self->contacts ],
	  props => [ map { $_->as_data_structure } $self->multiprops ],
	  ($depth > 0) ? (stocks => [ map { $_->as_data_structure($depth-1, $self) } $self->stocks->ordered_by_id ]) : (),
	 };
}


=head2 write_to_isatab



=cut

sub write_to_isatab {
  my ($self, $options) = @_;
  my $output_directory = $options->{directory} || die "must provide { directory => 'output_directory' } to write_to_isatab\n";

  my $isatab = $self->as_isatab();

  my $writer = Bio::Parser::ISATab->new(directory=>$output_directory);
  $writer->write($isatab);

  #
  # deeply examine $isatab for all assay 'raw_data_files'
  # and search for $isa_data->{assays}{$assay_name}{genotypes}
  # or $isa_data->{assays}{$assay_name}{phenotypes}
  # and for each raw_data_filename, make a copy of the data for $writer->write_study_or_assay()
  #
  my %filename2assays2genotypes;
  my %filename2assays2phenotypes;

  foreach my $study_assay (@{$isatab->{studies}[0]{study_assays}}) {
    foreach my $sample (keys %{$study_assay->{samples}}) {
      foreach my $assay (keys %{$study_assay->{samples}{$sample}{assays}}) {
	my $assay_isa = $study_assay->{samples}{$sample}{assays}{$assay};
	foreach my $g_or_p_filename ($assay_isa->{raw_data_files} ? keys($assay_isa->{raw_data_files}) : ()) {
	  if ($assay_isa->{genotypes}) {
	    $filename2assays2genotypes{$g_or_p_filename}{assays} //= ordered_hashref();
	    $filename2assays2genotypes{$g_or_p_filename}{assays}{$assay}{genotypes} = $assay_isa->{genotypes};
	  }
	  if ($assay_isa->{phenotypes}) {
	    $filename2assays2phenotypes{$g_or_p_filename}{assays} //= ordered_hashref();
	    $filename2assays2phenotypes{$g_or_p_filename}{assays}{$assay}{phenotypes} = $assay_isa->{phenotypes};
	  }
	}
      }
    }
  }
  foreach my $g_filename (keys %filename2assays2genotypes) {
    $writer->write_study_or_assay($g_filename, $filename2assays2genotypes{$g_filename},
				  ordered_hashref(
				   'Genotype Name' => 'reusable node',
				   'Type' => 'attribute',
				  ));
  }
  foreach my $p_filename (keys %filename2assays2phenotypes) {
    $writer->write_study_or_assay($p_filename, $filename2assays2phenotypes{$p_filename},
				  ordered_hashref(
				   'Phenotype Name' => 'reusable node',
				   'Observable' => 'attribute',
				   'Attribute' => 'attribute',
				   'Value' => 'attribute',
				  ));
  }
}


=head2 as_isatab

transform project into isatab data structure

will descend into samples, assays etc.

=cut


sub as_isatab {
  my $self = shift;

  my $isa = { studies => [ {} ] };
  my $study = $isa->{studies}[0];

  $study->{study_title} = $self->name;
  $study->{study_description} = $self->description;
  my $external_id = $study->{study_identifier} = $self->external_id;
  $study->{study_submission_date} = $self->submission_date;
  $study->{study_public_release_date} = $self->public_release_date;
  $study->{study_file_name} = 's_samples.txt';

  # start with the contacts because these throw the first error in the loader if not present
  foreach my $contact ($self->contacts) {
    # reverse the packing into Chado in ResultSet::Contact::find_or_create_from_isatab()
    my $description = $contact->description;
    my ($name, $place) = $description =~ /(.+?)(?: \((.+?)\))?$/;
    my ($first_name, $initials, $surname) = split " ", $name, 3;
    while (!$surname) {
      $surname = $initials;
      $initials = $first_name;
      $first_name = '';
    }
    if (!$first_name && $initials) {
      $first_name = $initials;
      $initials = '';
    }

    push @{$study->{study_contacts}}, {
				       study_person_email => $contact->name,
				       study_person_first_name => $first_name // '',
				       study_person_mid_initials => [ $initials // () ],
				       study_person_last_name => $surname,
				       study_person_address => $place // '',
		       };

  }


  # process the samples
  my $project_id = $self->stable_id;

  my $samples = $self->stocks->ordered_by_id;
  my $samples_data = $study->{sources}{$external_id}{samples} = ordered_hashref();
  while (my $sample = $samples->next) {
    my $projects = $sample->projects->ordered_by_id;
    my $samples_main_project = $projects->first;
    my $samples_main_project_id = $samples_main_project->stable_id;

    if ($samples_main_project_id eq $project_id) {
      my $sample_name = $sample->name;
      $samples_data->{$sample_name} = $sample->as_isatab($study);
      while (my $dependent_project = $projects->next) {
	my $schema = $self->result_source->schema;
	my $dependent_project_id = $dependent_project->stable_id;
	$schema->defer_exception_once("This project contains samples used in another dependent project $dependent_project_id. You must dump and delete that project first before dumping and deleting this one.");
      }
    } else {
      # this sample belongs to another project
      # so we dump it very simply
      my $sample_id = $sample->stable_id;
      $samples_data->{$sample_id} = $sample->as_isatab($study, $sample_id, $project_id);
    }
  }

  # all props are study designs
  foreach my $prop ($self->multiprops) {
    my ($sd, $design_type) = $prop->cvterms;
    my $dbxref = $design_type->dbxref;
    push @{$study->{study_designs}},
      {
       study_design_type => $design_type->name,
       study_design_type_term_source_ref => $dbxref->db->name,
       study_design_type_term_accession_number => $dbxref->accession,
      };

  }

  # publications (could move this code into Result/Publication.pm)
  foreach my $pub ($self->publications) {
    my $status = $pub->status;
    my $status_dbxref = $status ? $status->dbxref : undef;
    my $url = $pub->url;
    push @{$study->{study_publications}},
      {
       study_publication_doi => $pub->doi,
       study_pubmed_id => $pub->pubmed_id,
       study_publication_status => $status ? $status->name : '',
       study_publication_status_term_source_ref => $status_dbxref ? $status_dbxref->db->name : '',
       study_publication_status_term_accession_number => $status_dbxref ? $status_dbxref->accession : '',
       study_publication_title => $pub->title,
       study_publication_author_list => join('; ', $pub->authors),
       $url ? (comments => { URL => $url }) : (),
      };

  }


  # need to convert fallback_species_accession comments
  my $fsa = $self->fallback_species_accession;
  if (defined $fsa) {
    $study->{comments}{'fallback species accession'} = $fsa;
  }

  return $isa;
}

=head2 as_cytoscape_graph

returns a perl data structure corresponding to Cytoscape JSON format

It would be good to have a limit option (e.g. just show first 5 samples).

TBC more details here on what is actually dumped.

=cut

sub as_cytoscape_graph {
  my ($self, $nodes, $edges) = @_;

  $nodes //= {};
  $edges //= {};

  my $project_id = sprintf "project%08d", $self->id;

  $nodes->{$project_id} //= { data => {
				       id => $project_id,
				       name => $self->external_id,
				       type => 'project',
				      } };

  foreach my $sample ($self->stocks) {
    my $sample_id = sprintf "sample%08d", $sample->id;
    $nodes->{$sample_id} //= { data => {
					 id => $sample_id,
					 name => $sample->name,
					 type => 'sample',
					} };

    $edges->{"$project_id:$sample_id"} //= { data => {
						      id => "$project_id:$sample_id",
						      source => $project_id,
						      target => $sample_id,
						     } };

    my $not_used = $sample->as_cytoscape_graph($nodes, $edges);
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

1; # End of Bio::Chado::VBPopBio::Result::Project
