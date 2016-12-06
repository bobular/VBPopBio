package Bio::Chado::VBPopBio::Result::Experiment;

use strict;
use Carp;
use POSIX;
use feature 'switch';
use base 'Bio::Chado::Schema::Result::NaturalDiversity::NdExperiment';
__PACKAGE__->load_components(qw/+Bio::Chado::VBPopBio::Util::Subclass DynamicSubclass/);
__PACKAGE__->subclass({ nd_experiment_stocks => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentStock',
                        nd_experiment_projects => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentProject',
		        nd_geolocation => 'Bio::Chado::VBPopBio::Result::Geolocation',
			nd_experimentprops => 'Bio::Chado::VBPopBio::Result::Experimentprop',
		        nd_experiment_protocols => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentProtocol',
		        nd_experiment_genotypes => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentGenotype',
		        nd_experiment_phenotypes => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentPhenotype',
		        nd_experiment_dbxrefs => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentDbxref',
		        nd_experiment_contacts => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentContact',
			type => 'Bio::Chado::VBPopBio::Result::Cvterm',
		      });

__PACKAGE__->typecast_column('type_id');
__PACKAGE__->resultset_attributes({ order_by => 'nd_experiment_id' });

use aliased 'Bio::Chado::VBPopBio::Util::Multiprops';
use aliased 'Bio::Chado::VBPopBio::Util::Multiprop';
use aliased 'Bio::Chado::VBPopBio::Util::Extra';
use aliased 'Bio::Chado::VBPopBio::Util::Date';
use Tie::Hash::Indexed;

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

DEPRECATED?

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
    when ('species identification method') {
      bless $self, 'Bio::Chado::VBPopBio::Result::Experiment::SpeciesIdentificationAssay';
    }
    when ('sample manipulation') {
      bless $self, 'Bio::Chado::VBPopBio::Result::Experiment::SampleManipulation';
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

  Multiprops->add_multiprops_from_isatab_characteristics
    (
     row => $self,
     prop_relation_name => 'nd_experimentprops',
     characteristics => $assay_data->{characteristics},
    ) if ($assay_data->{characteristics});

  Multiprops->add_multiprops_from_isatab_comments
    (
     row => $self,
     prop_relation_name => 'nd_experimentprops',
     comments => $assay_data->{comments},
    ) if ($assay_data->{comments});

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
    my $types = $schema->types;
    my $protocols = $schema->protocols;
    my $cvterms = $schema->cvterms;
    my $dbxrefs = $schema->dbxrefs;
    my $contacts = $schema->contacts;

    while (my ($protocol_ref, $protocol_data) = each %{$protocols_data}) {

      my $protocol_info = $study->{study_protocol_lookup}{$protocol_ref};

      unless ($study->{study_protocol_lookup}{$protocol_ref}) {
	$schema->defer_exception_once("Protocol REF $protocol_ref not described in ISA-Tab.");
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
	$schema->defer_exception_once("Study Protocol Type ontology term for protocol $protocol_ref missing or not found\n");
	$protocol_type = $types->placeholder;
      }

      my $protocol = $protocols->find_or_new({
					      name => $self->stable_id.":".$protocol_ref, # $study->{study_identifier}.":".$protocol_ref,
					      type => $protocol_type,
					     });


      # only add more info to $protocol if it's newly created
      unless ($protocol->in_storage) {
	$protocol->insert; #now it's in the DB
	# set the description
	if (defined $protocol_info->{study_protocol_description}) {
	  $protocol->description($protocol_info->{study_protocol_description});
	}

	# set the URI
	if (defined $protocol_info->{study_protocol_uri}) {
	  $protocol->uri($protocol_info->{study_protocol_uri});
	}

	if (defined $protocol_info->{study_protocol_component_lookup}) {
	  while (my ($name, $data) = each %{$protocol_info->{study_protocol_component_lookup}}) {
	    # just add the component type as a single term multiprop
	    my $type;
	    if ($data->{study_protocol_component_type_term_accession_number} &&
		$data->{study_protocol_component_type_term_source_ref}) {
	      $type = $cvterms->find_by_accession
		({ term_source_ref => $data->{study_protocol_component_type_term_source_ref},
		   term_accession_number => $data->{study_protocol_component_type_term_accession_number} });
	      if (!defined $type) {
		$schema->defer_exception_once("failed to find term for $data->{study_protocol_component_type} ($data->{study_protocol_component_type_term_source_ref}:$data->{study_protocol_component_type_term_accession_number})");
	      }
	    }
	    my @cvterm_sentence = ($types->protocol_component);
	    my $text_value;
	    if (defined $type) {
	      push @cvterm_sentence, $type;
	    } else {
	      $text_value = "$name: $data->{study_protocol_component_type}";
	    }
	    $protocol->add_multiprop(Multiprop->new(cvterms=>\@cvterm_sentence, value=>$text_value));
	  }
	}
      }

      # link this experiment to the protocol
      my $nd_experiment_protocol = $self->find_or_create_related('nd_experiment_protocols', {  nd_protocol => $protocol } );

      # handle Date and Performer (store as experimentprops)
      # figure out what to do if there are multiple protocols for one experiment
      # as the date/performer info could be overwritten (but probably should not be)
      if (my $performer_email = $protocol_data->{performer}) {
	my $study_contact = $study->{study_contact_lookup}{$performer_email};
	my $contact = $contacts->find_or_create_from_isatab($study_contact);
	if ($contact) {
	  $self->add_to_contacts($contact);
	} else {
	  $schema->defer_exception_once("Can't find assay (protocol $protocol_ref) performer by email '$performer_email' in Study Contacts section");
	}
      }
      if (my $date = $protocol_data->{date}) {
	my ($start_date, $end_date) = split qr{/}, $date;
	if ($start_date && $end_date) {
	  my $valid_start = Date->simple_validate_date($start_date, $self);
	  my $valid_end = Date->simple_validate_date($end_date, $self);
	  if ($valid_start && $valid_end) {
	    $self->add_multiprop(Multiprop->new(cvterms=>[$types->start_date], value=>$valid_start));
	    $self->add_multiprop(Multiprop->new(cvterms=>[$types->end_date], value=>$valid_end));
	  } else {
	    $schema->defer_exception_once("Cannot parse start/end date '$date' for assay (protocol $protocol_ref).");
	  }
	} elsif ($start_date) {
	  my $valid_date = Date->simple_validate_date($start_date, $self);
	  if ($valid_date) {
	    $self->add_multiprop(Multiprop->new(cvterms=>[$types->date], value=>$valid_date));
	  } else {
	    $schema->defer_exception_once("Cannot parse date '$date' for assay (protocol $protocol_ref).");
	  }
	} else {
	  $schema->defer_exception_once("Some problem with date string '$date' in assay (protocol $protocol_ref).")
	}
      }

      if ($protocol_data->{parameter_values}) {

	my $multiprops = ordered_hashref(); # ->{param_prefix or param_name} = multiprop

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
	      $param_type_cvterm = $types->placeholder;
	    }
	  } else {
	    $schema->defer_exception_once("Protocol parameter '$param_name' has no ontology term");
	    $param_type_cvterm = $types->placeholder;
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
	  my $param_value;	# free text or number

	  # the param value is either a cvterm, or a text value with units or a text value
	  if ($param_data->{term_source_ref} && length($param_data->{term_accession_number})) {
	    my $param_value_cvterm = $cvterms->find_by_accession($param_data);
	    unless (defined $param_value_cvterm) {
	      $schema->defer_exception("Can't find parameter value cvterm $param_data->{term_source_ref}:($param_data->{term_accession_number}");
	      $param_value_cvterm = $types->placeholder;
	    }
	    push @cvterm_sentence, $param_value_cvterm;
	  } elsif (length($param_data->{value}) && $param_data->{unit}
		   && $param_data->{unit}{term_source_ref} &&
		   length($param_data->{unit}{term_accession_number})) {
	    my $param_unit_cvterm = $cvterms->find_by_accession($param_data->{unit});
	    unless (defined $param_unit_cvterm) {
	      $schema->defer_exception("Can't find parameter value's unit cvterm: $param_data->{unit}{term_source_ref}:$param_data->{unit}{term_accession_number}");
	      $param_unit_cvterm = $types->placeholder;
	    }
	    push @cvterm_sentence, $param_unit_cvterm;
	    $param_value = $param_data->{value};
	  } elsif (length($param_data->{value})) {
	    $param_value = $param_data->{value};
	  }

	  # build up multiprops based on the $param_name's prefix (anything before a dot)
	  # but if there is no prefix, use the whole $param_name
	  my ($param_prefix) = $param_name =~ /^(.+?)(?:\.|$)/;
	  my $mprop = $multiprops->{$param_prefix} ||= Multiprop->new(cvterms => [ ]);
	  if (defined $mprop->value) {
	    # if we pulled out out of the $multiprops cache it should have an undefined value attribute
	    $schema->defer_exception_once("Free text value not allowed for non-final prefixed protocol parameter '$param_name'");
	  } else {
	    # append to the cvterms
	    push @{$mprop->cvterms}, @cvterm_sentence;
	    # and add a free text value
	    $mprop->value($param_value) if (defined $param_value);
	  }
	}
	# add the multiprops to $self now
	foreach my $mprop (values %{$multiprops}) {
	  $self->add_multiprop($mprop);
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
  # warn "I am deleting experiment ".$self->stable_id."\n";

#   my $linkers = $self->related_resultset('nd_experiment_stocks');
#   while (my $linker = $linkers->next) {
#     # check that the stock is only attached to one experiment (has to be this one)
#     if ($linker->stock->experiments->count == 1) {
#       # warn "I am deleting stock ".$linker->stock->stable_id."\n";
#       $linker->stock->delete;
#     }
#     $linker->delete;
#   }

  # protocols
  my $linkers = $self->related_resultset('nd_experiment_protocols');
  while (my $linker = $linkers->next) {
    if ($linker->nd_protocol->nd_experiments->count == 1) {
      $linker->nd_protocol->delete;
    }
    $linker->delete;
  }

  # geolocations
  my $geoloc = $self->nd_geolocation;
  if ($geoloc->nd_experiments->count == 1) {
    $geoloc->delete;
  }

  # contacts
  $linkers = $self->related_resultset('nd_experiment_contacts');
  while (my $linker = $linkers->next) {
    if ($linker->contact->experiments->count == 1 && $linker->contact->projects->count == 0) {
      $linker->contact->delete;
    }
    $linker->delete;
  }

  # dbxref linkers (but don't delete them)
  $linkers = $self->related_resultset('nd_experiment_dbxrefs');
  while (my $linker = $linkers->next) {
    $linker->delete;
  }

  return $self->SUPER::delete();
}

=head2 relink

Links a project back to objects passed in the hashref

=cut

sub relink {
  my ($self, $links) = @_;

  if ($links->{projects}) {
    foreach my $project (@{$links->{projects}}) {
      $self->add_to_projects($project);
    }
  }
  if ($links->{stocks}) {
#    warn sprintf "%d and %d stocks and links for object %s\n", scalar(@{$links->{stocks}}), scalar(@{$links->{stock_link_type_ids}}), $self->stable_id;
    foreach my $stock (@{$links->{stocks}}) {
      my $link_type_id = shift @{$links->{stock_link_type_ids}};
#      warn "relinking ".$self->stable_id." to ".$stock->stable_id." type $link_type_id\n";
      $self->add_to_stocks($stock, { type_id => $link_type_id });
    }
  }
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

  my $first = $props->next;
  if ($props->next) {
    croak "experiment has too many external ids\n";
  } elsif (defined $first) {
    my $retval = $first->value;
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

my $VBA_db; # cached

sub stable_id {
  my ($self, $project) = @_;

  my $schema = $self->result_source->schema;
  $VBA_db //= $schema->dbs->find_or_create({ name => 'VBA' });

  #
  # first see if there is one single dbxref (connected via nd_experiment_dbxrefs)
  # and return its accession
  #
  my $quicksearch = $self->search_related
    ( 'nd_experiment_dbxrefs',
      { 'dbxref.db_id' => $VBA_db->id },
      { join => 'dbxref', prefetch => 'dbxref' }
    );

  if (my $first = $quicksearch->next) {
    if ($quicksearch->next) {
      croak "fatal error: too many VBA dbxrefs attached to nd_experiment: ".$self->external_id."\n";
    } else {
      return $first->dbxref->accession;
    }
  }

  croak("stable_id called without project arg") unless (defined $project);

  #
  # now look up stable ID in the persistent dbxref table
  #

  my $proj_extID_type = $schema->types->project_external_ID;
  my $expt_extID_type = $schema->types->experiment_external_ID;

  my $search = $VBA_db->dbxrefs->search
    ({
      'dbxrefprops.type_id' => $proj_extID_type->id,
      'dbxrefprops.value' => $project->external_id,
      'dbxrefprops_2.type_id' => $expt_extID_type->id,
      'dbxrefprops_2.value' => $self->external_id,
     },
     { join => [ 'dbxrefprops', 'dbxrefprops' ] }
    );

  my $first = $search->next;
  if (!defined $first) {
    # need to make a new ID

    # first, find the "highest" accession in dbxref for VBA
    my $last_dbxref_search = $schema->dbxrefs->search
      ({ db_id => $VBA_db->id },
       { order_by => { -desc => 'accession' },
         rows => 1 });

    my $next_number = 1;
    if (my $first_result = $last_dbxref_search->next) {
      my $acc = $first_result->accession;
      my ($prefix, $number) = $acc =~ /(\D+)(\d+)/;
      $next_number = $number+1;
    }

    # now create the dbxref
    my $new_dbxref = $schema->dbxrefs->create
      ({
	db => $VBA_db,
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
    return $new_dbxref->accession; # $self->stable_id would be nice but slower
  } elsif (!defined $search->next) {
    # set the stock.dbxref to the stored stable id dbxref
    $self->find_or_create_related('nd_experiment_dbxrefs', { dbxref=>$first });
    return $first->accession;
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

return an array of multiprops
optional filter cvterm (identity matching)

=cut

sub multiprops {
  my ($self, $filter) = @_;

  return Multiprops->get_multiprops
    ( row => $self,
      prop_relation_name => 'nd_experimentprops',
      filter => $filter,
    );
}


=head2 description

get/setter for description (stored via rank==0 prop)

usage

  $protocol->description("this is some text");
  print $protocol->description;


returns the text in both cases

=cut

sub description {
  my ($self, $description) = @_;
  return Extra->attribute
    ( value => $description,
      prop_type => $self->result_source->schema->types->description,
      prop_relation_name => 'nd_experimentprops',
      row => $self,
    );
}

=head2 result_summary

abstract base/warning method

returns a brief text summary of the assay results

=cut

sub result_summary {
  my ($self) = @_;
  warn "result_summary() not implemented for ".ref($self);
  return "not implemented yet!";
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
	  result_summary => $self->result_summary,
          props => [ map { $_->as_data_structure } $self->multiprops ],
	  protocols => [ map { $_->as_data_structure } $self->protocols ],
	  performers => [ map { $_->as_data_structure } $self->contacts ],
	  type => $self->type->name,
	 );
}


=head2 ordered_hashref

Wrapper for Tie::Hash::Indexed - returns a hashref which has already been tied to Tie::Hash::Indexed

no args.

usage: $foo->{bar} = ordered_hashref();  $foo->{bar}{hello} = 123;

=cut

sub ordered_hashref {
  my $ref = {};
  tie %{$ref}, 'Tie::Hash::Indexed';
  return $ref;
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

  # only certain subclasses will have child nodes
  # (phenotypes and genotypes maybe for now)

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

1; # End of Bio::Chado::VBPopBio::Result::Experiment
