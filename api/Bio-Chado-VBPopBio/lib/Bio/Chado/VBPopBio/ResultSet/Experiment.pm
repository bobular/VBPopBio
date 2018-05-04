package Bio::Chado::VBPopBio::ResultSet::Experiment;

use base 'DBIx::Class::ResultSet';
use Carp;
use strict;

=head1 NAME

Bio::Chado::VBPopBio::ResultSet::Experiment

=head1 SYNOPSIS

Experiment resultset with extra convenience functions


=head1 SUBROUTINES/METHODS

=head2 create

 Usage: $field_collections->create({ nd_geolocation => $geoloc });
        $genotype_assays->create();

 Desc: Convenience method to avoid having to set the type.
       If nd_geolocation is missing a default 'laboratory' object will be added

       find_or_create and other methods may not be needed because
       this table doesn't have a unique key constraints!

=cut

sub create {
  my ($self, $fields) = @_;

  $fields = {} unless defined $fields;
  $fields->{type} = $self->_type unless (defined $fields->{type});
  $fields->{nd_geolocation} = $self->result_source->schema->geolocations->find_or_create( { description => 'laboratory' } ) unless (defined $fields->{nd_geolocation});

  return $self->SUPER::create($fields);
}

=head2 find_and_delete_existing

Finds an experiment via its stable ID dbxref (project->external_id and assay_name),
saves a list of relationships that need to be reestablished later,
and then deletes it, returning the list of rels.

Returns undef if existing assay not found.

=cut

my $VBA_db; # cached

sub find_and_delete_existing {
  my ($self, $assay_name, $project, $stock) = @_;
  my $schema = $self->result_source->schema;
  $VBA_db //= $schema->dbs->find_or_create({ name => 'VBA' });

  my $proj_extID_type = $schema->types->project_external_ID;
  my $expt_extID_type = $schema->types->experiment_external_ID;

  my $search = $VBA_db->dbxrefs->search
    ({
      'dbxrefprops.type_id' => $proj_extID_type->id,
      'dbxrefprops.value' => $project->external_id,
      'dbxrefprops_2.type_id' => $expt_extID_type->id,
      'dbxrefprops_2.value' => $assay_name,
     },
     { join => [ 'dbxrefprops', 'dbxrefprops' ] }
    );

  my $first = $search->next;
  if (defined $first) {
    if (!defined $search->next) { # make sure only one
      my $linkers = $search->first->nd_experiment_dbxrefs;
      # stable ID should only be for one assay
      my $first_linker = $linkers->next;
      if (defined $first_linker) {
	if (!defined $linkers->next) { # should be only one!
	  my $assay = $first_linker->nd_experiment;

	  # save the projects and stocks to link to
	  # except the stock and project that are making this assay
	  # because those links will be remade anyway
	  my $links = { projects => [ grep { $_->id != $project->id } $assay->projects->all ],
			stocks =>  [ $assay->stocks->search({ 'stock.stock_id' => { '!=' => $stock->id } }, { order_by => 'stock.stock_id' })->all ],
		        stock_link_type_ids => [ $assay->nd_experiment_stocks->search({ stock_id => { '!=' => $stock->id } }, { order_by => 'stock_id' })->get_column('type_id')->all ],
		      };
	  # then delete the linkers
	  $assay->nd_experiment_projects->delete;
	  $assay->nd_experiment_stocks->delete;
	  # now delete the assay! (and phenotypes, genotypes etc
	  # but they will be added back again, don't worry)
	  $assay->delete;
	  return $links;
	} else {
	  croak("fatal problem with multiple assays linked to dbxref");
	}
      }
    } else {
      croak("fatal problem with multiple VBA dbxrefs");
    }
  }
  return undef;
}

=head2 find_and_link_existing

Finds the existing experiment object (if there) via $assay_name if it's a stable_id.
Links it to the project and returns it.
Otherwise returns undef.

=cut

sub find_and_link_existing {
  my ($self, $assay_name, $project) = @_;

  my $schema = $self->result_source->schema;

  if ($self->looks_like_stable_id($assay_name)) {
    my $existing_experiment = $self->find_by_stable_id($assay_name);
    if (defined $existing_experiment) {
      $existing_experiment->add_to_projects($project);
      return $existing_experiment;
    }
    $schema->defer_exception("$assay_name looks like a stable ID but we couldn't find it in the database");
  }
  return undef;
}

=head2 _type

Private method to return type cvterm for this subclass

Must be implemented in subclasses

=cut

sub _type {
  my ($self) = @_;
  croak("_type not implemented");
}


=head2 search_on_properties

################################################
    THE SEARCH_ON_* METHODS ARE DEPRECATED
may need revisiting if we do meta-projects again
################################################

    my $expts1 = $experiments->search_on_properties({ name => 'CDC light trap' });
    my $expts2 = $experiments->search_on_properties({ value => 'green' });
    # probably more useful to search on cvterm and value:
    my $expts3 = $experiments->search_on_properties(
                 { name => 'end time of day', value => '05:00' });
    # LIKE
    my $expts4 = $experiments->search_on_properties({ name => { like => 'Anoph%' } });

The interesting DBIx::Class thing here is that even though two joins are
specified in our code, only the joins which are needed are actually applied!
( test this by setting $schema->storage->debug(1) )

=cut

sub search_on_properties {
  my ($self, $conds) = @_;
  return $self->search($conds, { join => { nd_experimentprops => 'type' } });
}

=head2 search_on_properties_cv_acc

Needs a better name

    my $expts = $experiments->search_on_properties_cv_acc('MIRO:30000035');

assumes NAME:number format or will die


=cut

sub search_on_properties_cv_acc {
  my ($self, $cv_acc) = @_;
  my ($cv_name, $cv_number) = $cv_acc =~ /^([A-Za-z]+):(\d+)$/;
  $self->throw_exception("badly formatted CV/ontology accession - should be NAME:00012345 (any number of digits)")
    unless (defined $cv_name && defined $cv_number);

  return $self->search({ 'db.name' => $cv_name, accession => $cv_number },
		       { join => { 'nd_experimentprops' => { 'type' => { 'dbxref' => 'db'} } } });
}

=head2 filter_on_project

with undefined arg, do nothing

with $project object arg, restrict the search based on project membership

=cut

sub filter_on_project {
  my ($self, $project) = @_;

  my $result = $self;
  if (defined $project) {
    $result = $self->search({ project_id => $project->id },
			 { join => 'nd_experiment_projects' });
  }
  return wantarray ? $result->all : $result;
}


=head2 find_by_stable_id

returns a single result with the stable id

TO DO: describe failure modes (currently just returns undef if not found or ambiguous dbxrefs)

=cut

sub find_by_stable_id {
  my ($self, $stable_id) = @_;

  my $schema = $self->result_source->schema;
  $VBA_db //= $schema->dbs->find_or_create({ name => 'VBA' });

  my $search = $VBA_db->dbxrefs->search({ accession => $stable_id });

  if ($search->count == 1 && $search->first->nd_experiment_dbxrefs->count == 1) {
    return $search->first->nd_experiment_dbxrefs->first->nd_experiment;
  }
  return undef;
}

=head2 looks_like_stable_id

arg: ID

returns true if it matches VBA\d+

=cut

sub looks_like_stable_id {
  my ($self, $id) = @_;
  return $id =~ /^VBA\d{7}$/;
}

=head2 ordered_by_id

modifies resultset to make sure it is ordered
(replaces resultset_attributes order_by id)

=cut

sub ordered_by_id { shift->search({}, { order_by => 'nd_experiment_id' }) }

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
