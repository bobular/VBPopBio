package Bio::Chado::VBPopBio::Result::Project;

use Carp;
use POSIX;
use feature 'switch';
use base 'Bio::Chado::Schema::Result::Project::Project';
__PACKAGE__->load_components(qw/+Bio::Chado::VBPopBio::Util::Subclass/);
__PACKAGE__->subclass({
		       nd_experiment_projects => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentProject',
		       projectprops => 'Bio::Chado::VBPopBio::Result::Projectprop',
		      });
__PACKAGE__->resultset_attributes({ order_by => 'project_id' });

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

=cut

sub external_id {
  my ($self, $external_id) = @_;
  my $schema = $self->result_source->schema;
  my $proj_extID_type = $schema->types->project_external_ID;

  my $props = $self->search_related('projectprops',
				    { type_id => $proj_extID_type->id } );

  if ($props->count > 1) {
    croak "project has too many external ids\n";
  } elsif ($props->count == 1) {
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

  if ($search->count == 0) {
    # need to make a new ID

    # first, find the "highest" accession in dbxref for VBP
    my $last_dbxref_search = $schema->dbxrefs->search
      ({ 'db.name' => 'VBP' },
       { join => 'db',
	 order_by => { -desc => 'accession' },
         limit => 1 });

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

    return $new_dbxref->accession;
  } elsif ($search->count == 1) {
    return $search->first->accession;
  } else {
    croak "Too many dbxrefs for project ".$project->external_id." with dbxrefprop project external ID";
  }

}

=head2 delete

Deletes the project in a cascade which deletes all would-be orphan related objects.

It does not delete any would-be-orphaned contacts or publications.  Hopefully that will be
OK.  If not we will have to check that the contacts (or publications) don't belong to
several different object types before deletion.

=cut

sub delete {
  my $self = shift;

  my $linkers = $self->related_resultset('nd_experiment_projects');
  while (my $linker = $linkers->next) {
    # check that the experiment is only attached to one project (has to be this one)
    if ($linker->nd_experiment->projects->count == 1) {
      $linker->nd_experiment->delete;
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
  my ($self) = @_;

  return Multiprops->get_multiprops
    ( row => $self,
      prop_relation_name => 'projectprops',
    );
}



=head2 add_to_stocks

there is no project_stocks relationship in Chado so we have a nasty
hack using projectprops with a special type and a negative rank

usage: $project->add_to_stocks($stock_object);

returns the projectprop

=cut

sub add_to_stocks {
  my ($self, $stock) = @_;
  my $link_type = $self->result_source->schema->types->project_stock_link;

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

#	  projectprops => [ map {
#	    { $_->get_columns,
#		type => { $_->type->get_columns },
#	      } } $self->projectprops
#			  ],
	  ($depth > 0) ? (stocks => [ map { $_->as_data_structure($depth-1) } $self->stocks ]) : (),
	 };
}

=head2 as_data_for_jsonref

returns a json-like hashref of arrayrefs and hashrefs

this method is specifically for dojox.json.ref style json

=cut

sub as_data_for_jsonref {
  my ($self, $seen) = @_;
  my $id = 'p'.$self->project_id;
  if ($seen->{$id}++) {
    return { '$ref' => $id };
  } else {
    return {
	    id => $id,
	    name => $self->name,
	    description => $self->description,
	    stocks => [ map { $_->as_data_for_jsonref($seen) } $self->stocks ],
	    props => [ map { $_->as_data_for_jsonref($seen) } $self->projectprops ],
	 };
  }
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
