package Bio::Chado::VBPopBio::Types;

use Mouse;
use Memoize; # caches return values for approx 20% speedup (May 2013)
# sub memoize {} # control no Memoize

=head1 NAME

Bio::Chado::VBPopBio::Types

=head1 SYNOPSIS

Single class to provide commonly used cvterms used as types in props.

  my $props = $project->search_related('projectprops',
	       { type_id => $schema->types->project_external_ID->id });

=cut

=head1 ATTRIBUTES

=head2 schema

=cut

has 'schema' => (
		 is => 'ro',
		 isa => 'Bio::Chado::VBPopBio',
		 required => 1,
		);

=head2 project_external_ID

User-provided ID for projects, e.g. 2011-Smith-Mali-Aedes-larvae

=cut

sub project_external_ID {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0001052',
						   });
}
memoize('project_external_ID');

=head2 sample_external_ID

User-provided ID for samples, e.g. Mali-1234

=cut

sub sample_external_ID {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0001053',
						   });
}
memoize('sample_external_ID');

=head2 experiment_external_ID

User-provided ID for assays, e.g. Mali-1234

(note, "assay" will be used on all external facing aspects of VBPopBio
while the code will talk about experiments (i.e. nd_experiments)

=cut

sub experiment_external_ID {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv', # this is correct, but unintentionally "null"
						    term_accession_number=>'0001054',
						   });
}
memoize('experiment_external_ID');

=head2 date

VBcv:date

=cut

sub date {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0000705',
						   });
}
memoize('date');

=head2 start_date

VBcv:start date

=cut

sub start_date {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0000706',
						   });
}
memoize('start_date');

=head2 end_date

VBcv:end date

=cut

sub end_date {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0000707',
						   });
}
memoize('end_date');


=head2 submission_date

VBcv:submission_date

=cut

sub submission_date {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0000840'
						   });
}
memoize('submission_date');


=head2 public_release_date

VBcv:public_release_date

=cut

sub public_release_date {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0000841'
						   });
}
memoize('public_release_date');

=head2 last_modified_date

VBcv:last_modified_date

=cut

sub last_modified_date {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0001055'
						   });
}
memoize('last_modified_date');

=head2 creation_date

VBcv:creation_date

=cut

sub creation_date {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0001056'
						   });
}
memoize('creation_date');


=head2 placeholder

any old term to use during rolled back failed transactions, it won't get stored in the database

=cut

sub placeholder {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession( { term_source_ref => 'VBcv',
						      term_accession_number => '0000000',
						    } );
}


=head1 nd_experiment.type values

=head2 field_collection

=cut

sub field_collection {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0000691'
						   });
}
memoize('field_collection');

=head2 phenotype_assay

=cut


sub phenotype_assay {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0000690'
						   });
}
memoize('phenotype_assay');

=head2 genotype_assay

=cut

sub genotype_assay {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0000689'
						   });
}
memoize('genotype_assay');

=head2 species_identification_assay

=cut

sub species_identification_assay {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'MIRO',
						    term_accession_number=>'30000005' # species identification method
						   });
}
memoize('species_identification_assay');

=head2 sample_manipulation

=cut

sub sample_manipulation {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0001057'
						   });
}
memoize('sample_manipulation');

=head2 species_assay_result

=cut

sub species_assay_result {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({ term_accession_number => '0000961',
						     term_source_ref => 'VBcv',
						   });
}
memoize('species_assay_result');

=head2 project_stock_link

Used to link stocks to projects directly in Chado.  This is a bit of a hack!

=cut

sub project_stock_link {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0001059'
						   });
}
memoize('project_stock_link');

=head2 description

'Used to add descriptions to items in Chado via properties.'

=cut

sub description {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0001060'
						   });
}
memoize('description');

=head2 uri

=cut

sub uri {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0001062'
						   });
}
memoize('uri');

=head2 comment

'Used to identify multiprops as comments in Chado/JSON.'

=cut

sub comment {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0001063'
						   });
}
memoize('comment');

=head2 study_design

EFO:study design

=cut

sub study_design {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession( { term_source_ref => 'EFO',
						      term_accession_number => '0001426',
						    } );
}
memoize('study_design');

=head2 person

VBcv:person

'A cvterm used internally within VectorBase in the Chado contact table.'

Note: this term is never exposed to the public.  See ResultSet/Contact.pm for more.

=cut

sub person {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0000968' # Performer
						   });
}
memoize('person');

=head2 assay_creates_sample

VBcv:assay creates sample

'The sample attached to the assay has been generated by the assay (e.g. a field collection or a selective breeding experiment).'

=cut

sub assay_creates_sample {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0001064'
						   });
}
memoize('assay_creates_sample');

=head2 assay_uses_sample

VBcv:assay uses sample

'The sample attached to the assay has been used in an assay (e.g. as source material for DNA analysis, phenotype determination).'

=cut

sub assay_uses_sample {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0001065'
						   });
}
memoize('assay_uses_sample');

=head2 protocol_component

VBcv:protocol component

=cut

sub protocol_component {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0000848'
						   });
}
memoize('protocol_component');

=head2 vcf_file

'A cvterm used internally within Chado to store VCF file names for genotype assays.'

=cut

sub vcf_file {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0001066'
						   });
}
memoize('vcf_file');

=head2 collection_site

The ISA-Tab column heading/key under which the GAZ term (if known) is stored.

=cut

sub collection_site {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession( { term_source_ref => 'VBcv',
						      term_accession_number => '0000831',
						    } );
}
memoize('collection_site');


=head2 vis_configs

Internal project prop type
'A cvterm used internally within Chado to store visualisation config JSON for projects.'

=cut

sub vis_configs {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0001067'
						   });
}
memoize('vis_configs');

=head2 relationships_to_follow

special term which has a comma-delimited list of cvterm names for the
relationships that should be followed when descending to find parents.

e.g. relationships_to_follow->definition eq 'is_a,part_of';

=cut

sub relationships_to_follow {
  my $self = shift;
  my $term = $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0001068'
						   });
  # uncomment this to make a temporary change
  # $term->definition('is_a,part_of,located_in,has_quality');
  # $term->update;
  return $term;
}
memoize('relationships_to_follow');

=head1 best_species qualifiers

=head2 unambiguous

=cut

sub unambiguous {
  my $self = shift;
  my $term = $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0001069'
						   });
  # $term->definition('One or more species determination assays confirmed each other and the most specific species is reported.');
  # $term->update;
  return $term;
}
memoize('unambiguous');

=head2 ambiguous

=cut

sub ambiguous {
  my $self = shift;
  my $term = $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0001070'
						   });
  # $term->definition('Two or more species determination assays contradicted each other and the most appropriate higher level (more general) taxonomic term is reported.');
  # $term->update;
  return $term;
}
memoize('ambiguous');

=head2 derived

=cut

sub derived {
  my $self = shift;
  my $term = $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0001071'
						   });
  # $term->definition('The sample has had no species determination assays performed directly on it, so the species assignment has been made from the sample it was derived from.');
  # $term->update;
  return $term;
}
memoize('derived');

=head2 unknown

unknown blood meal source result

=cut

sub unknown {
  my $self = shift;
  my $term = $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0001049'
						   });
  $term->definition('The sample either had no species determination assays performed on it, or there were no usable results.');
  $term->update;
  return $term;
}
memoize('unknown');

=head2 project_default

=cut

sub project_default {
  my $self = shift;
  my $term = $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0001072'
						   });
  # $term->definition('No species determination assays were successfully performed, however submitters and curators have agreed on a project-wide fallback species or taxonomy term which is valid in these cases.');
  # $term->update;
  return $term;
}
memoize('project_default');


=head2 metaproject

=cut

sub metaproject {
  my $self = shift;
  my $term = $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0001073'
						   });
  # $term->definition('A project that consists of samples and assays entirely from pre-existing "primary" projects.');
  # $term->update;
  return $term;
}
memoize('metaproject');

=head2 published

EFO:published

=cut

sub published {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession( { term_source_ref => 'EFO',
						      term_accession_number => '0001796',
						    } );
}
memoize('published');

=head2 in_preparation

EFO:in preparation

=cut

sub in_preparation {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession( { term_source_ref => 'EFO',
						      term_accession_number => '0001795',
						    } );
}
memoize('in_preparation');



=head2 deprecated

'A flag for legacy species determination assays that should no longer be used when calculating the "best fit" species from a number of species assays'

=cut

sub deprecated {
  my $self = shift;
  my $term = $self->schema->cvterms->find_by_accession({
							term_source_ref=>'VBcv',
							term_accession_number=>'0001074'
						       });
  # $term->definition('A flag for legacy species determination assays that should no longer be used when calculating the "best fit" species from a number of species assays');
  # $term->update;
  return $term;
}
memoize('deprecated');


=head2 fallback_species_accession

Internal project prop type

'A cvterm used internally within Chado to store the VBsp:nnnnnnn accession for the species term that should be assigned to samples lacking an assay-based assertion.'

=cut

sub fallback_species_accession {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession({
						    term_source_ref=>'VBcv',
						    term_accession_number=>'0001075'
						   });
}
memoize('fallback_species_accession');


=head2 collection_duration_in_days

Internal project prop type

=cut

sub collection_duration_in_days {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession( { term_source_ref => 'VBcv',
						      term_accession_number => '0001009',
						    } );
}
memoize('collection_duration_in_days');



#
# this is a subsection - please add new terms above the previous head1
#

__PACKAGE__->meta->make_immutable;

1;
