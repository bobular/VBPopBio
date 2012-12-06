package Bio::Chado::VBPopBio::Result::Stock;

use base 'Bio::Chado::Schema::Result::Stock::Stock';
__PACKAGE__->load_components('+Bio::Chado::VBPopBio::Util::Subclass');
__PACKAGE__->resultset_class('Bio::Chado::VBPopBio::ResultSet::Stock'); # required because BCS has a custom resultset
__PACKAGE__->subclass({
		       nd_experiment_stocks => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentStock',
		       stockprops => 'Bio::Chado::VBPopBio::Result::Stockprop',
		       organism => 'Bio::Chado::VBPopBio::Result::Organism',
		       type => 'Bio::Chado::VBPopBio::Result::Cvterm',
		      });
__PACKAGE__->resultset_attributes({ order_by => 'stock_id' });

use aliased 'Bio::Chado::VBPopBio::Util::Multiprops';
use Carp;
use POSIX;

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


=head2 experiments_by_type

Helper method not intended for general use.
See field_collections, phenotype_assays for usage.

=cut

sub experiments_by_type {
  my ($self, $type) = @_;
  return $self->experiments->search({ 'nd_experiment.type_id' => $type->cvterm_id });
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

  my $db = $schema->dbs->find_or_create({ name => 'VBS' });
  my $proj_extID_type = $schema->types->project_external_ID;
  my $samp_extID_type = $schema->types->sample_external_ID;

  my $search = $db->dbxrefs->search
    ({
      'dbxrefprops.type_id' => $proj_extID_type->id,
      'dbxrefprops.value' => $project->external_id,
      'dbxrefprops_2.type_id' => $samp_extID_type->id,
      'dbxrefprops_2.value' => $self->external_id,
     },
     { join => [ 'dbxrefprops', 'dbxrefprops' ] }
    );

  if ($search->count == 0) {
    # need to make a new ID

    # first, find the "highest" accession in dbxref for VBP
    my $last_dbxref_search = $schema->dbxrefs->search
      ({ 'db.name' => 'VBS' },
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
  } elsif ($search->count == 1) {
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

=head2 multiprops

get a arrayref of multiprops

=cut

sub multiprops {
  my ($self) = @_;

  return Multiprops->get_multiprops
    ( row => $self,
      prop_relation_name => 'stockprops',
    );
}


=head2 as_data_structure

returns a json-like hashref of arrayrefs and hashrefs

=cut

sub as_data_structure {
  my ($self, $depth) = @_;
  $depth = INT_MAX unless (defined $depth);

  return {
      id => $self->stable_id, # use stable_id when ready
      name => $self->name,
      external_id => $self->external_id,

      # make sure 'recursion' won't go too deep using $depth argument
      # however, no depth checks for some contained objects, such as organism, cvterms etc
      type => $self->type->as_data_structure,

      props => [ map { $_->as_data_structure } $self->multiprops ],

      # need to provide Result::Organism::as_data_structure:
      organism => $self->organism ? $self->organism->as_data_structure : 'NULL',

      # organism_id => $self->organism_id,

      ($depth > 0) ? (
		      field_collections => [ map { $_->as_data_structure($depth) } $self->field_collections ],
		      species_identification_assays => [ map { $_->as_data_structure($depth) } $self->species_identification_assays ],
		      genotype_assays => [ map { $_->as_data_structure($depth) } $self->genotype_assays ],
		      phenotype_assays => [ map { $_->as_data_structure($depth) } $self->phenotype_assays ],
		     )
	  : (),


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

1; # End of Bio::Chado::VBPopBio::Result::Stock
