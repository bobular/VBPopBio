package Bio::Chado::VBPopBio::Result::Experiment;

use strict;
use Carp;
use POSIX;
use feature 'switch';
use base 'Bio::Chado::Schema::Result::NaturalDiversity::NdExperiment';
__PACKAGE__->load_components(qw/+Bio::Chado::VBPopBio::Util::Subclass DynamicSubclass/);
__PACKAGE__->subclass({ nd_experiment_stocks => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentStock',
		        nd_geolocation => 'Bio::Chado::VBPopBio::Result::Geolocation',
			nd_experimentprops => 'Bio::Chado::VBPopBio::Result::Experimentprop',
		        nd_experiment_protocols => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentProtocol',
		        nd_experiment_genotypes => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentGenotype',
		        nd_experiment_phenotypes => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentPhenotype',
		        nd_experiment_dbxrefs => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentDbxref',
			type => 'Bio::Chado::VBPopBio::Result::Cvterm',
		      });

__PACKAGE__->typecast_column('type_id');
__PACKAGE__->resultset_attributes({ order_by => 'nd_experiment_id' });

use aliased 'Bio::Chado::VBPopBio::Util::Multiprops';
use aliased 'Bio::Chado::VBPopBio::Util::Multiprop';

=head1 NAME

Bio::Chado::VBPopBio::Result::Experiment

=head1 SYNOPSIS

Experiment object with extra convenience functions.
Specialised experiment classes can be found in the.
Bio::Chado::VBPopBio::Result::Experiment::* namespace.

=head1 MANY-TO-MANY RELATIONSHIPS

=head2 stocks

Type: many_to_many

Returns a list of stocks

Related object: Bio::Chado::Schema::Stock::Stock

=cut

__PACKAGE__->many_to_many
    (
     'stocks',
     'nd_experiment_stocks' => 'stock',
    );


=head2 projects

Type: many_to_many

Returns a list of projects

Related object: Bio::Chado::Schema::Result::Project::Project

=cut

__PACKAGE__->many_to_many
    (
     'projects',
     'nd_experiment_projects' => 'project',
    );

=head2 nd_protocols and protocols

Type: many_to_many

Returns a list of protocols

Related object: Bio::Chado::Schema::Result::NaturalDiversity::NdProtocol

=cut

__PACKAGE__->many_to_many
    (
     'protocols',
     'nd_experiment_protocols' => 'nd_protocol',
    );

__PACKAGE__->many_to_many
    (
     'nd_protocols',
     'nd_experiment_protocols' => 'nd_protocol',
    );


=head2 genotypes

Type: many_to_many

Returns a list of genotypes

Related object: Bio::Chado::Schema::Result::Genetic::Genotype

=cut

__PACKAGE__->many_to_many
    (
     'genotypes',
     'nd_experiment_genotypes' => 'genotype',
    );

=head2 phenotypes

Type: many_to_many

Returns a list of phenotypes

Related object: Bio::Chado::Schema::Result::Phenotype::Phenotype

=cut

__PACKAGE__->many_to_many
    (
     'phenotypes',
     'nd_experiment_phenotypes' => 'phenotype',
    );

=head2 contacts

Type: many_to_many

Returns a list of contacts

Related object: Bio::Chado::Schema::Result::Contact::Contact

=cut

__PACKAGE__->many_to_many
    (
     'contacts',
     'nd_experiment_contacts' => 'contact',
    );

=head2 dbxrefs

Type: many_to_many

Returns a list of dbxrefs

Related object: Bio::Chado::Schema::Result::General::Dbxref

=cut

__PACKAGE__->many_to_many
    (
     'dbxrefs',
     'nd_experiment_dbxrefs' => 'dbxref',
    );

=head2 pubs

Type: many_to_many

Returns a list of pubs (publications)

Related object: Bio::Chado::Schema::Result::Pub::Pub

=cut

__PACKAGE__->many_to_many
    (
     'pubs',
     'nd_experiment_pubs' => 'pub',
    );





=head1 SUBROUTINES/METHODS

=head2 stocks

Get all stocks for this experiment.

=cut

###
# now provided by Bio::Chado::Schema (http://github.com/bobular/Bio-Chado-Schema)
###
# sub stocks {
#   my ($self) = @_;
#   return $self->search_related('nd_experiment_stocks')->search_related('stock');
# }
###

=head2 properties

=cut

sub properties {
  my ($self) = @_;
  return $self->search_related('nd_experimentprops', {}, { order_by => 'rank' });
}

=head2 classify

Sets correct subclass (FieldCollection, PhenotypeAssay etc) when object is
created, fetched or have its type value changed.  Not for general
use.  See DBIx::Class::DynamicSubclass.

=cut

sub classify {
  my $self = shift;

  # this is what the new (>5.10) Perl switch statement looks like
  given ($self->type->name) {
    when ('field collection') {
      bless $self, 'Bio::Chado::VBPopBio::Result::Experiment::FieldCollection';
    }
    when ('phenotype assay') {
      bless $self, 'Bio::Chado::VBPopBio::Result::Experiment::PhenotypeAssay';
    }
    when ('genotype assay') {
      bless $self, 'Bio::Chado::VBPopBio::Result::Experiment::GenotypeAssay';
    }
    when ('species identification assay') {
      bless $self, 'Bio::Chado::VBPopBio::Result::Experiment::SpeciesIdentificationAssay';
    }
    default {
      # do nothing
    }
  }
}

=head2 annotate_from_isatab

  Usage: $assay->annotate_from_isatab($assay_data)

  Return value: none

  Args: hashref of ISA-Tab data: $study->{study_assays}[0]{samples}{SAMPLE_NAME}{assays}{ASSAY_NAME}

Adds description, comments, characteristics to the assay/nd_experiment object

=cut

sub annotate_from_isatab {
  my ($self, $assay_data) = @_;

  if (defined $assay_data->{description}) {
    $self->description($assay_data->{description});
  }
}


=head2 add_to_protocols_from_isatab

  Usage: $genotype_assay->add_to_protocols_from_isatab($assay_data->{protocols});

  Return value: a Perl list of the protocols added.

  Args:  hashref to $study->{study_assays}[0]{samples}{SAMPLE_NAME}{assays}{ASSAY_NAME}{protocols}

Adds zero or more protocols from ISA-Tab data.

I guess we are doing this here (in Experiment) to avoid subclassing the NdProtocol class.
But if we have to do that one day, then maybe we should follow the pattern and have a
Protocol::create_from_isatab method.

=cut

sub add_to_protocols_from_isatab {
  my ($self, $protocols_data, $ontologies, $study) = @_;
  my @protocols;

  if ($protocols_data) {
    my $schema = $self->result_source->schema;
    my $protocols = $schema->protocols;
    my $cvterms = $schema->cvterms;
    my $dbxrefs = $schema->dbxrefs;

    while (my ($protocol_ref, $protocol_data) = each %{$protocols_data}) {
      my $protocol_info = $study->{study_protocol_lookup}{$protocol_ref};

      unless ($study->{study_protocol_lookup}{$protocol_ref}) {
	$schema->defer_exception("Protocol REF $protocol_ref not described in ISA-Tab.");
	next;
      }

# now that protocols are mostly ontologised (in i_investigation.txt)
# the description shouldn't be mandatory
#      croak "No description for $protocol_ref" unless ($study->{study_protocol_lookup}{$protocol_ref}{study_protocol_description});

      my $protocol_type;

      # protocol.type is mandatory
      if ($protocol_info->{study_protocol_type_term_source_ref} &&
	  length($protocol_info->{study_protocol_type_term_accession_number})) {

	$protocol_type = $cvterms->find_by_accession({ 'term_source_ref' => $protocol_info->{study_protocol_type_term_source_ref},
						       'term_accession_number' => $protocol_info->{study_protocol_type_term_accession_number},
						     });

      }

      if (!defined $protocol_type) {
	# maybe create a placeholder here and store the error
	# $protocol_info->{study_protocol_type}
	$schema->defer_exception("Study Protocol Type ontology term for protocol $protocol_ref missing or not found\n");
	$protocol_type = $schema->types->placeholder;
      }

      my $protocol = $protocols->find_or_create({
						 name => $study->{study_identifier}.":".$protocol_ref,
						 type => $protocol_type,
						});

      # set the description
      if (defined $protocol_info->{study_protocol_description}) {
	$protocol->description($protocol_info->{study_protocol_description});
      }

      # link this experiment to the protocol
      my $nd_experiment_protocol = $self->find_or_create_related('nd_experiment_protocols', {  nd_protocol => $protocol } );

      if ($protocol_data->{parameter_values}) {

	# if we had a nd_experiment_protocolprops table we could attach the props to $nd_experiment_protocol
	# but we'll have to attach them to the nd_experiment ($self) for now

	while (my ($param_name, $param_data) = each %{$protocol_data->{parameter_values}}) {

	  #
	  # 1. find or create a temporary VBcv cvterm for the parameter TYPE
	  #

	  my $param_type_acc = $protocol_info->{study_protocol_parameter_lookup}{$param_name}{study_protocol_parameter_name_term_accession_number};
	  my $param_type_db = $protocol_info->{study_protocol_parameter_lookup}{$param_name}{study_protocol_parameter_name_term_source_ref};
	  my $param_type_cvterm;
	  if (length($param_type_acc) && $param_type_db) {
	    $param_type_cvterm = $cvterms->find_by_accession
	      ({
		term_source_ref => $param_type_db,
		term_accession_number => $param_type_acc,
	       });
	    unless (defined $param_type_cvterm) {
	      $schema->defer_exception("Cant find term '$param_type_db:$param_type_acc' for protocol parameter '$param_name'");
	      $param_type_cvterm = $schema->types->placeholder;
	    }
	  } else {
	    $schema->defer_exception("Protocol parameter '$param_name' has no ontology term");
	    $param_type_cvterm = $cvterms->create_with({ name => $param_name,
							 cv => 'VBcv',
						       });
	  }

	  #
	  # 2. find a cvterm for the parameter value,
	  #    or text-value + unit cvterms
	  #    or plain text value
	  #
	  # create a multiprop sentence and add it
	  # (e.g. "insecticide permethrin" or "concentration mg/ml 100")
	  #

	  my @cvterm_sentence = ($param_type_cvterm);
	  my $param_value; # free text or number

	  # the param value is either a cvterm, or a text value with units or a text value
	  if ($param_data->{term_source_ref} && length($param_data->{term_accession_number})) {
	    my $param_value_cvterm = $cvterms->find_by_accession($param_data);
	    unless (defined $param_value_cvterm) {
	      $schema->defer_exception("Can't find parameter value cvterm $param_data->{term_source_ref}:($param_data->{term_accession_number}");
	      $param_value_cvterm = $schema->types->placeholder;
	    }
	    push @cvterm_sentence, $param_value_cvterm;
	  } elsif (length($param_data->{value}) && $param_data->{unit}
		   && $param_data->{unit}{term_source_ref} &&
		   length($param_data->{unit}{term_accession_number})) {
	    my $param_unit_cvterm = $cvterms->find_by_accession($param_data->{unit});
	    unless (defined $param_unit_cvterm) {
	      $schema->defer_exception("Can't find parameter value's unit cvterm: $param_data->{unit}{term_source_ref}:$param_data->{unit}{term_accession_number}");
	      $param_unit_cvterm = $schema->types->placeholder;
	    }
	    push @cvterm_sentence, $param_unit_cvterm;
	    $param_value = $param_data->{value};
	  } elsif (length($param_data->{value})) {
	    $param_value = $param_data->{value};
	  }
	  $self->add_multiprop(Multiprop->new(
					      cvterms => \@cvterm_sentence,
					      value => $param_value
					     ));
	}
      }

      push @protocols, $protocol;
    }
  }

  return @protocols;
}


=head2 delete

deletes the experiment in a cascade which deletes all would-be orphan related objects

=cut

sub delete {
  my $self = shift;

  my $linkers = $self->related_resultset('nd_experiment_stocks');
  while (my $linker = $linkers->next) {
    # check that the stock is only attached to one experiment (has to be this one)
    if ($linker->stock->experiments->count == 1) {
      $linker->stock->delete;
    }
    $linker->delete;
  }
  my $geoloc = $self->nd_geolocation;
  if ($geoloc->nd_experiments->count == 1) {
    $geoloc->delete;
  }

  return $self->SUPER::delete();
}


=head2 external_id

getter/setter for project external id ("Assay Name" from ISA-Tab)

returns undef if not found

=cut

sub external_id {
  my ($self, $external_id) = @_;
  my $schema = $self->result_source->schema;
  my $expt_extID_type = $schema->types->experiment_external_ID;

  my $props = $self->search_related('nd_experimentprops',
				    { type_id => $expt_extID_type->id } );

  if ($props->count > 1) {
    croak "experiment has too many external ids\n";
  } elsif ($props->count == 1) {
    my $retval = $props->first->value;
    croak "attempted to set a new external id ($external_id) for experiment with existing id ($retval)\n" if (defined $external_id && $external_id ne $retval);

    return $retval;
  } else {
    if (defined $external_id) {
      # no existing external id so create one
      # create the prop and return the external id
      $self->find_or_create_related('nd_experimentprops',
							 {
							  type => $expt_extID_type,
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

Returns a dbxref->accession from

1. [quick] single matching nd_experiment_dbxrefs from db.name=VBA (croak if multiple hits)
2. by looking up a dbxref from VBA with dbxrefprop "project external ID" == $project->external_id
   and dbxrefprop "experiment external ID" == $self->external_id
   It will create a new entry with the next available accession if there is none.

=cut

sub stable_id {
  my ($self, $project) = @_;

  my $schema = $self->result_source->schema;

  my $db = $schema->dbs->find_or_create({ name => 'VBA' });


  #
  # first see if there is one single dbxref (connected via nd_experiment_dbxrefs)
  # and return its accession
  #
  my $quicksearch = $self->search_related
    ( 'nd_experiment_dbxrefs',
      { 'dbxref.db_id' => $db->id },
      { join => 'dbxref' }
    );

  if ((my $count = $quicksearch->count()) == 1) {
    return $quicksearch->first->dbxref->accession;
  } elsif ($count > 1) {
    croak "fatal error: too many VBA dbxrefs attached to nd_experiment: ".$self->external_id."\n";
  }

  #
  # now look up stable ID in the persistent dbxref table
  #

  my $proj_extID_type = $schema->types->project_external_ID;
  my $expt_extID_type = $schema->types->experiment_external_ID;

  my $search = $db->dbxrefs->search
    ({
      'dbxrefprops.type_id' => $proj_extID_type->id,
      'dbxrefprops.value' => $project->external_id,
      'dbxrefprops_2.type_id' => $expt_extID_type->id,
      'dbxrefprops_2.value' => $self->external_id,
     },
     { join => [ 'dbxrefprops', 'dbxrefprops' ] }
    );

  if ($search->count == 0) {
    # need to make a new ID

    # first, find the "highest" accession in dbxref for VBP
    my $last_dbxref_search = $schema->dbxrefs->search
      ({ 'db.name' => 'VBA' },
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
	accession => sprintf("VBA%07d", $next_number),
	dbxrefprops => [ {
			 type => $proj_extID_type,
			 value => $project->external_id,
			 rank => 0,
			},
		        {
			 type => $expt_extID_type,
			 value => $self->external_id,
			 rank => 0,
			},
		       ]
       });
    # set the stock.dbxref to the new dbxref
    $self->find_or_create_related('nd_experiment_dbxrefs', { dbxref=>$new_dbxref });
    # warn "new stable id ".$new_dbxref->accession." for $self ".$self->external_id."\n";
    return $new_dbxref->accession; # $self->stable_id would be nice but slower
  } elsif ($search->count == 1) {
    # set the stock.dbxref to the stored stable id dbxref
    my $old_dbxref = $search->first;
    $self->find_or_create_related('nd_experiment_dbxrefs', { dbxref=>$old_dbxref });
    return $old_dbxref->accession;
  } else {
    croak "Too many VBA dbxrefs for project ".$project->external_id." + experiment ".$self->external_id."\n";
  }

}


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
      prop_relation_name => 'nd_experimentprops',
    );
}

=head2 multiprops

get a arrayref of multiprops

=cut

sub multiprops {
  my ($self) = @_;

  return Multiprops->get_multiprops
    ( row => $self,
      prop_relation_name => 'nd_experimentprops',
    );
}


=head description

get/setter for description (stored via rank==0 prop)

usage

  $protocol->description("this is some text");
  print $protocol->description;


returns the text in both cases

=cut

sub description {
  my ($self, $description) = @_;
  my $schema = $self->result_source->schema;

  if (defined $description) {
    $self->find_or_create_related('nd_experimentprops',
				  {
				   type => $schema->types->description,
				   value => $description,
				   rank => 0,
				  });
  } else {
    my $propsearch = $self->search_related('nd_experimentprops',
					   {
					    type_id => $schema->types->description->id,
					    rank => 0,
					   });
    if ($propsearch->count == 1) {
      $description = $propsearch->first->value;
    }
  }
  return $description;
}


=head2 as_data_structure

returns a json-like hashref of arrayrefs and hashrefs

=cut

sub as_data_structure {
  my ($self, $depth) = @_;
  $depth = INT_MAX unless (defined $depth);

  return {
	  $self->basic_info,
          warning => 'Warning: Experiment Result has not been sub-classed!',
	 };
}

=head2 basic_info (private/protected)

returns hash of key/value pairs for Experiment base class

=cut

sub basic_info {
  my ($self) = @_;

  return (
	  id => $self->stable_id,
	  name => $self->external_id,
	  description => $self->description,
          props => [ map { $_->as_data_structure } $self->multiprops ],
	  protocols => [ map { $_->as_data_structure } $self->protocols ],
	 );
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

1; # End of Bio::Chado::VBPopBio::Result::Experiment
