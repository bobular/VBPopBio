package Bio::Chado::VBPopBio::ResultSet::Experiment::PhenotypeAssay;

use base 'Bio::Chado::VBPopBio::ResultSet::Experiment';
use Carp;
use strict;
use aliased 'Bio::Chado::VBPopBio::Util::Multiprops';

my %phenotype_data_cache; # see GenotypeAssay.pm

=head1 NAME

Bio::Chado::VBPopBio::ResultSet::Experiment::PhenotypeAssay

=head1 SYNOPSIS

PhenotypeAssay resultset with extra convenience functions


=head1 SUBROUTINES/METHODS

=head2 new

overloaded constructor adds default resultset filtering on phenotype assay type_id

=cut

sub new {
  my ($class, $source, $attribs) = @_;
  $attribs = {} unless $attribs;
  $attribs->{where}{type_id} = $source->schema->types->phenotype_assay->cvterm_id;
  return $class->SUPER::new($source, $attribs);
}

=head2 create_from_isatab

 Usage: $phenotype_assays->create_from_isatab($assay_name, $assay_data, $project, $stock, $ontologies, $study, $isa_parser);

 Desc: This method creates genoype assay nd_experiment from the isatab assay sample hashref
 Ret : a new Experiment::PhenotypeAssay row (is a NdExperiment)
 Args: string ASSAY_NAME
       hashref $isa->{studies}[N]{study_assay_lookup}{'phenotype assay'}{samples}{SAMPLE_NAME}{assays}{ASSAY_NAME}
       Project object (Bio::Chado::VBPopBio)
       hashref $isa->{ontology_lookup} from ISA-Tab returned from Bio::Parser::ISATab
       hashref ISA-Tab current study (used for protocols)
       Bio::Parser::ISATab object

=cut

sub create_from_isatab {
  my ($self, $assay_name, $assay_data, $project, $stock, $ontologies, $study, $isa_parser) = @_;

  # maybe the assay is in use by another project so wasn't deleted
  # but we still need to delete it and relink it afterwards
  my $saved_links = $self->find_and_delete_existing($assay_name, $project, $stock);
  # maybe $assay_name is a stable ID and we just need to "borrow" an assay from an existing project
  my $phenotype_assay = $self->find_and_link_existing($assay_name, $project);

  unless (defined $phenotype_assay) {

    # create the nd_experiment and stock linker type
    my $schema = $self->result_source->schema;
    my $cvterms = $schema->cvterms;
    my $dbxrefs = $schema->dbxrefs;
    my $phenotypes = $schema->phenotypes;

    # always create a new nd_experiment object
    $phenotype_assay = $self->create();
    $phenotype_assay->external_id($assay_name);
    my $stable_id = $phenotype_assay->stable_id($project);

    # add description, characteristics etc
    $phenotype_assay->annotate_from_isatab($assay_data);

    # add it to the project
    $phenotype_assay->add_to_projects($project);

    # add the protocols
    $phenotype_assay->add_to_protocols_from_isatab($assay_data->{protocols}, $ontologies, $study);

    # load the phenotype data from the phenotype file(s)
    foreach my $p_file_name (keys %{$assay_data->{raw_data_files}}) {
      my $phenotype_data =
	# see comments in GenotypeAssay.pm about cache key
	$phenotype_data_cache{$project->stable_id.'/'.$p_file_name} ||=
	  $isa_parser->parse_study_or_assay($p_file_name, undef,
					    {
					     'Phenotype Name' => 'reusable node',
					     'Observable' => 'attribute',
					     'Attribute' => 'attribute',
					     'Value' => 'attribute',
					    });

      if ($phenotype_data->{assays}{$assay_name}{phenotypes}) {
	while (my ($name, $data) = each %{$phenotype_data->{assays}{$assay_name}{phenotypes}}) {
	  my $uniquename = "$stable_id:$name";

	  my $observable = $cvterms->find_by_accession($data->{observable});
	  unless (defined $observable || keys %{$data->{observable}} == 0) {
	    $schema->defer_exception_once("Cannot load non-empty Observable ontology term for phenotype $name in $p_file_name");
	    $observable = $schema->types->placeholder;
	  }

	  my $attribute = $cvterms->find_by_accession($data->{attribute});
	  unless (defined $attribute || keys %{$data->{attribute}} == 0) {
	    $schema->defer_exception_once("Cannot load non-empty Attribute ontology term for phenotype $name in $p_file_name");
	    $attribute = $schema->types->placeholder;
	  }

	  my $value_term = $cvterms->find_by_accession($data->{value});

	  my $unit;
	  if (!defined $value_term && defined $data->{value}{unit}) {
	    $unit = $cvterms->find_by_accession($data->{value}{unit});
	  }

	  my $phenotype = $phenotypes->find_or_create({
						       name => $name,
						       uniquename => $uniquename,
						       defined $observable ? ( observable => $observable ) : (),
						       defined $attribute ? ( attr => $attribute ) : (),
						       defined $value_term ? ( cvalue => $value_term ) : ( value => $data->{value}{value} ),
						       # hijacking the assay/evidence cvterm for units
						       defined $unit ? ( assay => $unit ) : (),
						      });

	  # link to the nd_experiment
	  my $assay_link = $phenotype->find_or_create_related('nd_experiment_phenotypes',
							      {
							       nd_experiment => $phenotype_assay });

	  #
	  # Deal with multiple "Characteristics [term name (ONTO:accession)]" columns
	  # by adding multiprops for them
	  #
	  Multiprops->add_multiprops_from_isatab_characteristics
	    ( row => $phenotype,
	      prop_relation_name => 'phenotypeprops',
	      characteristics => $data->{characteristics} ) if ($data->{characteristics});

	}
      } else {
	$schema->defer_exception_once("possibly missing phenotype data for $assay_name in $p_file_name");
      }
    }
  }

  $phenotype_assay->relink($saved_links) if ($saved_links);

  return $phenotype_assay;
}

=head2 _type

private method to return type cvterm for this subclass

=cut

sub _type {
  my ($self) = @_;
  return $self->result_source->schema->types->phenotype_assay;
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
