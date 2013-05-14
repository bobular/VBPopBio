package Bio::Chado::VBPopBio::ResultSet::Experiment::GenotypeAssay;

use base 'Bio::Chado::VBPopBio::ResultSet::Experiment';
use Carp;
use strict;
use aliased 'Bio::Chado::VBPopBio::Util::Multiprops';

my %genotype_data_cache; # filename => $isatab_like_data_structure ( {sample_name}{assays}{assay_name}... )

# the last level is an array of rows in the file (hashrefs, key=>val)

=head1 NAME

Bio::Chado::VBPopBio::ResultSet::Experiment::GenotypeAssay

=head1 SYNOPSIS

GenotypeAssay resultset with extra convenience functions

=head1 SUBROUTINES/METHODS

=head2 new

overloaded constructor adds default resultset filtering on genotype assay type_id

=cut

sub new {
  my ($class, $source, $attribs) = @_;
  $attribs = {} unless $attribs;
  $attribs->{where}{type_id} = $source->schema->types->genotype_assay->cvterm_id;
  return $class->SUPER::new($source, $attribs);
}

=head2 create_from_isatab

 Usage: $genotype_assays->create_from_isatab($assay_name, $assay_data, $project, $ontologies, $study, $isa_parser);

 Desc: This method creates genoype assay nd_experiment from the isatab assay sample hashref
 Ret : a new Experiment::GenotypeAssay row (is a NdExperiment)
 Args: string ASSAY_NAME
       hashref $isa->{studies}[N]{study_assay_lookup}{'genotype assay'}{samples}{SAMPLE_NAME}{assays}{ASSAY_NAME}
       Project object (Bio::Chado::VBPopBio)
       hashref $isa->{ontology_lookup} from ISA-Tab returned from Bio::Parser::ISATab
       hashref ISA-Tab current study (used for protocols)
       Bio::Parser::ISATab object

=cut

sub create_from_isatab {
  my ($self, $assay_name, $assay_data, $project, $ontologies, $study, $isa_parser) = @_;

  # maybe the assay is in use by another project so wasn't deleted
  # but we still need to delete it and relink it afterwards
  my $saved_links = $self->find_and_delete_existing($assay_name, $project);
  # maybe $assay_name is a stable ID and we just need to "borrow" an assay from an existing project
  my $genotype_assay = $self->find_and_link_existing($assay_name, $project);

  unless (defined $genotype_assay) {
    # create the nd_experiment and stock linker type
    my $schema = $self->result_source->schema;
    my $cvterms = $schema->cvterms;
    my $dbxrefs = $schema->dbxrefs;
    my $genotypes = $schema->genotypes;

    # always create a new nd_experiment object
    $genotype_assay = $self->create();
    $genotype_assay->external_id($assay_name);
    my $stable_id = $genotype_assay->stable_id($project);

    # add description, characteristics etc
    $genotype_assay->annotate_from_isatab($assay_data);

    # add to project
    $genotype_assay->add_to_projects($project);

    # add the protocols
    $genotype_assay->add_to_protocols_from_isatab($assay_data->{protocols}, $ontologies, $study);


    # load the genotype data from the g_xxxxx ISA-Tab-like sheet(s)
    foreach my $g_file_name (keys %{$assay_data->{raw_data_files}}) {
      # but don't read in VCF files!
      if ($g_file_name =~ /\.vcf$/i) {
	$genotype_assay->vcf_file($g_file_name);
      } else {
	my $genotype_data =
	  $genotype_data_cache{$g_file_name} ||=
	    $isa_parser->parse_study_or_assay($g_file_name, undef,
					      {
					       'Type' => 'attribute',
					       'Genotype Name' => 'reusable node',
					      });

	if ($genotype_data->{assays}{$assay_name}{genotypes}) {
	  while (my ($name, $data) = each %{$genotype_data->{assays}{$assay_name}{genotypes}}) {
	    #...
	    # assay stable id + Genotype Name
	    my $uniquename = "$stable_id:$name";
	    my $description = $data->{description} || '';
	    my $type = $cvterms->find_by_accession($data->{type});
	    unless (defined $type) {
	      $schema->defer_exception_once("Cannot load Type ontology term for genotype $name in $g_file_name");
	      $type = $schema->types->placeholder;
	    }
	    my $genotype = $genotypes->find_or_create({
						       name => $name,
						       uniquename => $uniquename,
						       description => $description,
						       type => $type,
						      });

	    # link to the nd_experiment
	    my $assay_link = $genotype->find_or_create_related('nd_experiment_genotypes',
							       {
								nd_experiment => $genotype_assay });


	    #
	    # Deal with multiple "Characteristics [term name (ONTO:accession)]" columns
	    # by adding multiprops for them
	    #
	    Multiprops->add_multiprops_from_isatab_characteristics
	      ( row => $genotype,
		prop_relation_name => 'genotypeprops',
		characteristics => $data->{characteristics} ) if ($data->{characteristics});

	  }
	} else {
	  $schema->defer_exception_once("possibly missing genotype data for $assay_name in $g_file_name");
	}
      }
    }
  }

  $genotype_assay->relink($saved_links) if ($saved_links);

  return $genotype_assay;
}


=head2 _type

private method to return type cvterm for this subclass

=cut

sub _type {
  my ($self) = @_;
  return $self->result_source->schema->types->genotype_assay;
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
