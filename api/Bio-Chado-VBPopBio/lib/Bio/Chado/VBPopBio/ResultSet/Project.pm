package Bio::Chado::VBPopBio::ResultSet::Project;

use strict;
use warnings;
use base 'DBIx::Class::ResultSet';
use Carp;
use Bio::Parser::ISATab 0.05;
use aliased 'Bio::Chado::VBPopBio::Util::Multiprop';
use aliased 'Bio::Chado::VBPopBio::Util::Multiprops';

=head1 NAME

Bio::Chado::VBPopBio::ResultSet::Project

=head1 SYNOPSIS

Project resultset with extra convenience functions


=head1 SUBROUTINES/METHODS

=head2 experiments

alias for nd_experiments

=cut

sub experiments {
  my $self = shift;
  return $self->nd_experiments;
}



=head2 create_from_isatab

 Usage: $projects->create_from_isatab({ directory   => 'isatab/directory' });

 Desc: This method loads the ISA-Tab data and creates a project corresponding to ONE study in the ISA-Tab file.
 Ret : a new Project row
 Args: hashref of:
         { directory   => 'my_isatab_directory',
         }

When we eventually support multi-study ISA-Tab, we will have to
link them to the "investigation" with the project_relationship table.

=cut

sub create_from_isatab {
  my ($self, $opts) = @_;

  croak "No valid ISA-Tab directory supplied" unless ($opts->{directory} && -d $opts->{directory});

  my $parser = Bio::Parser::ISATab->new(directory=>$opts->{directory});
  my $isa = $parser->parse();
  my @studies = @{$isa->{studies}};
  croak "No studies in ISA-Tab" unless (@studies);
  croak "Multiple studies not yet supported" if (@studies > 1);

  my $ontologies = $isa->{ontology_lookup};
  carp "Warning, no ontologies in ISA-Tab" unless (keys %$ontologies);

  my $schema = $self->result_source->schema;
  my $cvterms = $schema->cvterms;
  my $types = $schema->types;

  my $study = shift @studies;
  Bio::Parser::ISATab::create_lookup($study, 'study_contacts', 'study_contact_lookup', 'study_person_email');

  croak "Study has no contacts\n" unless (keys %{$study->{study_contact_lookup}});

  # do some sanity checks
  my $study_title = $study->{study_title};
  croak "Study has no title" unless ($study_title);
  my $study_description = $study->{study_description};
  croak "Study has no description" unless ($study_description);
  my $study_external_id = $study->{study_identifier};
  croak "Study has no external ID" unless ($study_external_id);

  #
  # check for project with project external ID already
  # (has been tested, but is not in a test suite)
  #
  if (my $existing_project = $self->find_by_external_id($study_external_id)) {
    my $existing_stable_id = $existing_project->stable_id;
    croak "Project $existing_stable_id is already loaded with external ID '$study_external_id' - aborting."
  }

  #
  # now create the project object
  # it will fail with runtime exception if 'name' exists
  #
  my $project = $self->create( {
				name => $study_title,
				description => $study_description,
			       } );
  $project->external_id($study_external_id);

  #
  # getting the stable ID creates one
  # should there be an alias/wrapper for stable_id such as reserve_stable_id
  my $stable_id = $project->stable_id;
  croak "cannot create/retrieve a stable ID" unless ($stable_id);
  # same for creation date (create it by asking for it)
  my $creation_date = $project->creation_date;
  # more explicit udpate for modification date
  my $modification_date = $project->update_modification_date;

  #
  # set some date attributes (via props)
  #
  if ($study->{study_submission_date}) {
    $project->submission_date($study->{study_submission_date});
  } else {
    $schema->defer_exception("Missing mandatory study submission date in ISA-Tab investigation sheet");
  }
  if ($study->{study_public_release_date}) {
    $project->public_release_date($study->{study_public_release_date});
  }

  #
  # set the fallback species
  #
  if ($study->{comments}{'fallback species accession'}) {
    # do some basic format checks
    if ($study->{comments}{'fallback species accession'} =~ /^\w+:\d+$/) {
      $project->fallback_species_accession($study->{comments}{'fallback species accession'});
    }
  }

  #
  # add study design multiprops
  #
  my $sd = $types->study_design;
  foreach my $study_design (@{$study->{study_designs}}) {
    my $design_term = $cvterms->find_by_accession
      ({ term_source_ref => $study_design->{study_design_type_term_source_ref},
	 term_accession_number => $study_design->{study_design_type_term_accession_number}
       });
    if (defined $design_term) {
      $project->add_multiprop(Multiprop->new( cvterms=>[ $sd, $design_term ] ));
    } else {
      $schema->defer_exception("Could not find ontology term $study_design->{study_design_type} ($study_design->{study_design_type_term_source_ref}:$study_design->{study_design_type_term_accession_number})");
    }
  }

  #
  # add the study publications
  #
  my $publications = $schema->publications;
  foreach my $study_publication (@{$study->{study_publications}}) {
    my $publication = $publications->find_or_create_from_isatab($study_publication);
    $project->add_to_publications($publication) if ($publication);
  }

  #
  # add the study contacts
  #
  my $contacts = $schema->contacts;
  foreach my $study_contact (@{$study->{study_contacts}}) {
    my $contact = $contacts->find_or_create_from_isatab($study_contact);
    $project->add_to_contacts($contact) if ($contact);
  }

  if ($study->{study_factors} && @{$study->{study_factors}}) {
    warn "Not currently loading Study Factors (but they are in the ISA-Tab)\n";
  }

  # create stand-alone stocks
  # these are pulled out of the $study hash tree in the order
  # they were first seen in the ISA-Tab files

  my $stocks = $schema->stocks;
  my %stocks;
 SOURCE:
  while (my ($source_id, $source_data) = each %{$study->{sources}}) {

    # we are currently ignoring all source annotations
    $schema->defer_exception("ISA-Tab Source characteristics/protocols were encountered but no code exists to load them")
      if (keys %{$source_data->{characteristics}} || keys %{$source_data->{protocols}});

    while (my ($sample_id, $sample_data) = each %{$source_data->{samples}}) {
      $stocks{$sample_id} ||= $stocks->find_or_create_from_isatab($sample_id, $sample_data, $project, $ontologies, $study);
      $stocks{$sample_id}->add_to_projects($project);

      # this might be used for dry-run testing (see bin/load_project.pl)
      last SOURCE if ($opts->{sample_limit} && keys %stocks >= $opts->{sample_limit});
    }
  }

  # add nd_experiments for stocks (and link these to project)

  my $assays = $study->{study_assays};  # array reference

  my %field_collections;
  my %species_identification_assays;
  my %genotype_assays;
  my %phenotype_assays;

  my $assay_creates_stock = $types->assay_creates_sample;
  my $assay_uses_stock = $types->assay_uses_sample;

  # for each stock that we already added
  while (my ($sample_id, $stock) = each %stocks) {

    foreach my $assay (@$assays) {

      # FIELD COLLECTION
      if ($assay->{study_assay_measurement_type} eq 'field collection') {
	if (defined(my $sample_data = $assay->{samples}{$sample_id})) {
	  while (my ($assay_name, $assay_data) = each %{$sample_data->{assays}}) {
	    my $assay = $field_collections{$assay_name} ||= $schema->field_collections->create_from_isatab($assay_name, $assay_data, $project, $stock, $ontologies, $study);
	    # link each field collection (newly created or already existing) to the stock
	    $assay->add_to_stocks($stock, { type => $assay_creates_stock })
	      unless ($assay->search_related('nd_experiment_stocks',
					     { stock_id => $stock->id, type_id => $assay_creates_stock->id })->count);
	    # you could have added linker props with the following inside the second argument
	    # nd_experiment_stockprops => [ { type => $some_cvterm, value => 77 } ]
	  }
	} else {
	  # need a warning for missing assay data for a particular sample?
	  # add below for other assay types too if needed!
	}
      }

      # SPECIES IDENTIFICATION ASSAY
      elsif ($assay->{study_assay_measurement_type} eq 'species identification assay') {
	if (defined(my $sample_data = $assay->{samples}{$sample_id})) {
	  while (my ($assay_name, $assay_data) = each %{$sample_data->{assays}}) {
	    my $assay = $species_identification_assays{$assay_name} ||=
 $schema->species_identification_assays->create_from_isatab($assay_name, $assay_data, $project, $stock, $ontologies, $study);
	    $assay->add_to_stocks($stock, { type => $assay_uses_stock })
	      unless ($assay->search_related('nd_experiment_stocks',
					     { stock_id => $stock->id, type_id => $assay_uses_stock->id })->count);
	    # this assay also 'produces' a stock (which contains the organism information)
	    # but that is linked within ResultSet::SpeciesIdentificationAssay
	  }
	}
      }


      # GENOTYPE ASSAY
      elsif ($assay->{study_assay_measurement_type} eq 'genotype assay') {
	if (defined(my $sample_data = $assay->{samples}{$sample_id})) {
	  while (my ($assay_name, $assay_data) = each %{$sample_data->{assays}}) {
	    my $assay = $genotype_assays{$assay_name} ||= $schema->genotype_assays->create_from_isatab($assay_name, $assay_data, $project, $stock, $ontologies, $study, $parser);
	    $assay->add_to_stocks($stock, { type => $assay_uses_stock })
	      unless ($assay->search_related('nd_experiment_stocks',
					     { stock_id => $stock->id, type_id => $assay_uses_stock->id })->count);
	  }
	}
      }

      # PHENOTYPE ASSAY
      elsif ($assay->{study_assay_measurement_type} eq 'phenotype assay') {
	if (defined(my $sample_data = $assay->{samples}{$sample_id})) {
	  while (my ($assay_name, $assay_data) = each %{$sample_data->{assays}}) {
	    my $assay = $phenotype_assays{$assay_name} ||= $schema->phenotype_assays->create_from_isatab($assay_name, $assay_data, $project, $stock, $ontologies, $study, $parser);
	    $assay->add_to_stocks($stock, { type => $assay_uses_stock })
	      unless ($assay->search_related('nd_experiment_stocks',
					     { stock_id => $stock->id, type_id => $assay_uses_stock->id })->count);
	  }
	}
      }

      # WRONG ASSAY TYPE
      else {
	$schema->defer_exception_once("Unknown Study Assay Measurement Type: $assay->{study_assay_measurement_type}");
      }
    }

  }

#  use Data::Dumper;
#  $Data::Dumper::Indent = 1;
#  carp Dumper($isa);

  return $project;
}


=head2 find_by_stable_id 

Returns a project result by stable id.

Because there's no direct link between the dbxref and the project, the
route is a bit tortuous.  Looks for VBP dbxref with the accession then
finds the external_id - then looks for the project with the
external_id as a projectprop.

=cut

sub find_by_stable_id {
  my ($self, $stable_id) = @_;
  my $schema = $self->result_source->schema;
  my $proj_extID_type = $schema->types->project_external_ID;
  my $db = $schema->dbs->find_or_create({ name => 'VBP' });

  my $search = $db->dbxrefs->search({ accession => $stable_id });
  if ($search->count == 1) {
    # now get the external id from the dbxrefprops
    my $dbxref = $search->first;
    my $propsearch = $dbxref->dbxrefprops->search({ type_id => $proj_extID_type->id });
    if ($propsearch->count == 1) {
      my $external_id = $propsearch->first->value;
      return $self->find_by_external_id($external_id);
    }
  }
  return undef;
}

=head2 find_by_external_id

look up the project via projectprops external id

=cut


sub find_by_external_id {
  my ($self, $external_id) = @_;
  my $schema = $self->result_source->schema;
  my $proj_extID_type = $schema->types->project_external_ID;
  my $search = $self->search_related
    ("projectprops",
     {
      type_id => $proj_extID_type->id,
      value => $external_id,
     }
    );
  if ($search->count == 1) {
    return $search->first->project;
  }

  return undef;
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
			      )->search_related('stock', { }, { distinct => 1  });
}

=head2 looks_like_stable_id

check to see if VBP\d{7}

=cut

sub looks_like_stable_id {
  my ($self, $id) = @_;
  return $id =~ /^VBP\d{7}$/;
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
