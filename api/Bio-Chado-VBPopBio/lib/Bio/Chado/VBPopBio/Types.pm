package Bio::Chado::VBPopBio::Types;

use Moose;


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
  return $self->schema->cvterms->create_with
    ({ name => 'project external ID',
       cv => 'VBcv',
       db => 'VBcv',
       description => 'An ID of the format YYYY-AuthorSurname-Keyword(s) - '.
       'should be unique with respect to all VectorBase population data submissions.'
     });
}

=head2 sample_external_ID

User-provided ID for samples, e.g. Mali-1234

=cut

sub sample_external_ID {
  my $self = shift;
  return $self->schema->cvterms->create_with
    ({ name => 'sample external ID',
       cv => 'VBcv',
       db => 'VBcv',
       description => 'A sample ID (originating in ISA-Tab Sample Name column).'.
       'It need not follow any formatting rules, but it'.
       'should be unique within a data submission.'
     });
}

=head2 experiment_external_ID

User-provided ID for assays, e.g. Mali-1234

(note, "assay" will be used on all external facing aspects of VBPopBio
while the code will talk about experiments (i.e. nd_experiments)

=cut

sub experiment_external_ID {
  my $self = shift;
  return $self->schema->cvterms->create_with
    ({ name => 'assay external ID',
       cv => 'VBcv',
       description => 'An assay ID (originating in ISA-Tab Assay Name column).'.
       'It need not follow any formatting rules, but it'.
       'should be unique within the entire ISA-Tab data submission.'
     });
}

=head2 date

VBcv:date

=cut

sub date {
  my $self = shift;
  return $self->schema->cvterms->find_by_name({ term_source_ref => 'VBcv',
						term_name => 'date' });

}

=head2 start_date

VBcv:start date

=cut

sub start_date {
  my $self = shift;
  return $self->schema->cvterms->find_by_name({ term_source_ref => 'VBcv',
						term_name => 'start date' });

}

=head2 end_date

VBcv:end date

=cut

sub end_date {
  my $self = shift;
  return $self->schema->cvterms->find_by_name({ term_source_ref => 'VBcv',
						term_name => 'end date' });
}


=head2 submission_date

VBcv:submission_date

=cut

sub submission_date {
  my $self = shift;
  return $self->schema->cvterms->create_with({ name => 'submission date',
					       cv => 'VBcv',
					       db => 'VBcv',
					       description => 'The date at which the data was submitted to VectorBase.',
					     });
}

=head2 public_release_date

VBcv:public_release_date

=cut

sub public_release_date {
  my $self = shift;
  return $self->schema->cvterms->create_with({ name => 'public release date',
					       cv => 'VBcv',
					       db => 'VBcv',
					       description => 'The date at or after which the data was made available on VectorBase.',
					     });
}


=head2 placeholder

any old term

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
  return $self->schema->cvterms->find_by_name({ term_name => 'field collection',
						term_source_ref => 'VBcv',
					      });
}

=head2 phenotype_assay

=cut


sub phenotype_assay {
  my $self = shift;
  return $self->schema->cvterms->find_by_name({ term_name => 'phenotype assay',
						term_source_ref => 'VBcv',
					      });
}

=head2 genotype_assay

=cut

sub genotype_assay {
  my $self = shift;
  return $self->schema->cvterms->find_by_name({ term_name => 'genotype assay',
						term_source_ref => 'VBcv',
					      });
}

=head2 species_identification_assay

=cut

sub species_identification_assay {
  my $self = shift;
  return $self->schema->cvterms->find_by_name({ term_name => 'species identification method',
						term_source_ref => 'MIRO',
					      });
}

=head2 sample_manipulation

=cut

sub sample_manipulation {
  my $self = shift;
  return $self->schema->cvterms->create_with({ name => 'sample manipulation',
					       cv => 'VBcv',
					       db => 'VBcv',
					       description => 'A laboratory or field-based event during which a sample or population is transformed into another sample or population.',
					     });
}


=head2 species_assay_result

=cut

sub species_assay_result {
  my $self = shift;
  warn "Temporarily using wrong term for species_assay_result\n";
  return $self->schema->cvterms->find_by_name({ term_name => 'species list',
						term_source_ref => 'VBcv',
					      });
}


=head2 project_stock_link

Used to link stocks to projects directly in Chado.  This is a bit of a hack!

=cut

sub project_stock_link {
  my $self = shift;
  return $self->schema->cvterms->create_with({ name => 'project stock link',
					       cv => 'TEMPcv',
					       db => 'TEMPcv',
					       dbxref => 'project_stock_link',
					       description => 'Used to link stocks to projects directly in Chado.  This is a bit of a hack.',
					     });
}


=head2 description

=cut

sub description {
  my $self = shift;
  return $self->schema->cvterms->create_with({ name => 'description',
					       cv => 'VBcv',
					       db => 'VBcv',
					       description => 'Used to add descriptions to items in Chado via properties.',
					     });
}

=head2 uri

=cut

sub uri {
  my $self = shift;
  return $self->schema->cvterms->create_with({ name => 'URI',
					       cv => 'VBcv',
					       db => 'VBcv',
					       description => 'Used to add URIs to items in Chado via properties.',
					     });
}


=head2 comment

=cut

sub comment {
  my $self = shift;
  return $self->schema->cvterms->create_with({ name => 'comment',
					       cv => 'VBcv',
					       db => 'VBcv',
					       description => 'Used to identify multiprops as comments in Chado/JSON.',
					     });
}

=head2 study_design

EFO:study design

=cut

sub study_design {
  my $self = shift;
  return $self->schema->cvterms->find_by_accession( { term_source_ref => 'EFO',
						      term_accession_number => '0001426',
						    } );
}

=head2 person

VBcv:person

=cut

sub person {
  my $self = shift;
  return $self->schema->cvterms->create_with({ name => 'person',
					       cv => 'VBcv',
					       db => 'VBcv',
					       description => 'A cvterm used internally within VectorBase in the Chado contact table.',
					     });
}

=head2 assay_creates_sample

VBcv:assay creates sample

=cut

sub assay_creates_sample {
  my $self = shift;
  return $self->schema->cvterms->create_with({ name => 'assay creates sample',
					       cv => 'VBcv',
					       db => 'VBcv',
					       description => 'The sample attached to the assay has been generated by the assay (e.g. a field collection or a selective breeding experiment).',
					     });
}

=head2 assay_uses_sample

VBcv:assay uses sample

=cut

sub assay_uses_sample {
  my $self = shift;
  return $self->schema->cvterms->create_with({ name => 'assay uses sample',
					       cv => 'VBcv',
					       db => 'VBcv',
					       description => 'The sample attached to the assay has been used in an assay (e.g. as source material for DNA analysis, phenotype determination).',
					     });
}

=head2 protocol_component

VBcv:protocol component

=cut

sub protocol_component {
  my $self = shift;
  return $self->schema->cvterms->create_with({ name => 'protocol component',
					       cv => 'VBcv',
					       db => 'VBcv',
					       description => 'A piece of equipment, software or other component of a protocol which is always the same from assay to assay.',
					     });
}

=head2 vcf_file

VBcv:protocol component

=cut

sub vcf_file {
  my $self = shift;
  return $self->schema->cvterms->create_with({ name => 'VCF file',
					       cv => 'VBcv',
					       db => 'VBcv',
					       description => 'A cvterm used internally within Chado to store VCF file names for genotype assays.',
					     });
}

=head2 protocol_parameter_group

TAKES AN ARGUMENT!
integer 1 .. 3

=cut

sub protocol_parameter_group {
  my ($self, $int) = @_;
warn "protocol_parameter_group is deprecated!\n";
  my $schema = $self->schema;
  unless ($int =~ /^[123]$/) {
    $schema->defer_exception_once("Protocol parameter group number '$int' not valid");
    return $self->placeholder;
  }
  return $schema->cvterms->create_with({ name => "protocol parameter group $int",
					 cv => 'VBcv',
					 db => 'VBcv',
					 description => 'A cvterm used internally within VectorBase Chado to group otherwise identical parameter values (e.g. multiple insecticides).',
					     });
}

1;
