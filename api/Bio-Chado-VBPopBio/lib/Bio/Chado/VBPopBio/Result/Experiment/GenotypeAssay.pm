package Bio::Chado::VBPopBio::Result::Experiment::GenotypeAssay;

use strict;
use base 'Bio::Chado::VBPopBio::Result::Experiment';
__PACKAGE__->load_components(qw/+Bio::Chado::VBPopBio::Util::Subclass/);
__PACKAGE__->subclass({ }); # must call this routine even if not setting up relationships.

use aliased 'Bio::Chado::VBPopBio::Util::Extra';
use Bio::Chado::VBPopBio::Util::Functions qw/ordered_hashref/;

=head1 NAME

Bio::Chado::VBPopBio::Result::Experiment::GenotypeAssay

=head1 SYNOPSIS

Genotype assay


=head1 SUBROUTINES/METHODS

=head2 result_summary

returns a brief HTML summary of the assay results

=cut

sub result_summary {
  my ($self) = @_;
  my $schema = $self->result_source->schema;

  my $method = 'unknown method';
  my @protocols = $self->protocols->all;
  if (@protocols) {
    $method = join ', ', sort map { $_->type->name } @protocols;
  }

  my $text = "no genotypes";
  if ($self->vcf_file) {
    $text = "variants shown in genome browser";
  } else {
    # there could be "simple" Chado genotypes as well as VCF/genomic ones
    # but let's assume there are not!
    my @text;
    my $max_shown = 4;
    my $genotypes = $self->genotypes;
    # avoid using resultset->count
    while (my $genotype = $genotypes->next) {
      push @text, $genotype->description || $genotype->name;
      if (@text == $max_shown) {
	push @text, sprintf "; and %d more genotypes", $genotypes->count - $max_shown;
	last;
      }
    }
    $text = join '; ', @text if (@text);
  }
  return "$text ($method)";
}

=head2 vcf_file

get/setter for VCF file name (stored via rank==0 prop)

usage

  $protocol->vcf_file("foo.vcf");
  print $protocol->vcf_file;


returns the text in both cases

=cut

sub vcf_file {
  my ($self, $vcf_file) = @_;
  return Extra->attribute
    ( value => $vcf_file,
      prop_type => $self->result_source->schema->types->vcf_file,
      prop_relation_name => 'nd_experimentprops',
      row => $self,
    );
}

=head2 genome_browser_path

If the relevant properties are available
(provided by ISA-Tab columns
Characteristics [reference_genome (SO:0001505)]
Characteristics [experimental result region (SO:0000703)]
)
then return a path that would open the genome browser at the
given location with the variation set track turned on.

This function now uses the Project ID in the genome browser path.
If an assay belongs to multiple projects, the "first" project will be used.
(It seems that the projects come back in order of being attached to the assay.
But this was tested with multi-project samples.)

(This should possibly be in the Javascript client.)

=cut

sub genome_browser_path {
  my ($self) = @_;
  my $schema = $self->result_source->schema;
  my $cvterms = $schema->cvterms;
  my $ref_type = $cvterms->find_by_accession({term_source_ref => 'SO', term_accession_number=>'0001505'});
  my $region_type = $cvterms->find_by_accession({term_source_ref => 'SO', term_accession_number=>'0000703'});
  my ($project_id) = map { $_->stable_id } $self->projects;

  my @multiprops = $self->multiprops;
  if (@multiprops >= 2) {
    my ($ref, $var_set, $region);
    foreach my $multiprop ($self->multiprops) {
      my $prop_key_id = $multiprop->cvterms->[0]->cvterm_id;
      if ($prop_key_id == $ref_type->cvterm_id) {
	$ref = $multiprop->value;
      } elsif ($prop_key_id == $region_type->cvterm_id) {
	$region = $multiprop->value;
      }
    }

    if ($ref && $region && $project_id) {
      return "/$ref/Location/View?db=core;r=$region;contigviewbottom=variation_feature_variation_$project_id=normal";
    }
  }
  return undef;
}

=head2 as_data_structure

return a data structure for jsonification

=cut

sub as_data_structure {
  my ($self, $depth) = @_;

  return {
      $self->basic_info,
      genotypes => [ map { $_->as_data_structure } $self->genotypes->all ],
      vcf_file => $self->vcf_file,
      genome_browser_path => $self->genome_browser_path,
	 };
}


=head2 delete

deletes the experiment in a cascade which deletes all would-be orphan related objects

=cut

sub delete {
  my $self = shift;

  my $linkers = $self->related_resultset('nd_experiment_genotypes');
  while (my $linker = $linkers->next) {
    if ($linker->genotype->experiments->count == 1) {
      $linker->genotype->delete;
    }
    $linker->delete;
  }

  return $self->SUPER::delete();
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

  foreach my $genotype ($self->genotypes) {
    my $genotype_id = sprintf "genotype%08d", $genotype->id;
    $nodes->{$genotype_id} //= { data => {
					id => $genotype_id,
					name => $genotype->name,
					type => 'genotype',
				       } };
    $edges->{"$assay_id:$genotype_id"} //= { data => {
						    id => "$assay_id:$genotype_id",
						    source => $assay_id,
						    target => $genotype_id,
						   } } ;
  }

  my $graph = {
	       elements => {
			    nodes => [ values(%$nodes) ],
			    edges => [ values(%$edges) ],
			   }
	      };

  return $graph;
}


=head2 as_isatab

handles the g_genotype file export

=cut

sub as_isatab {
  my ($self, $study, $assay_filename) = @_;

  my $isa = $self->SUPER::as_isatab($study, $assay_filename);

  my $genotypes_filename = $assay_filename;
  $genotypes_filename =~ s/^a_/g_/;

  my $vcf_file = $self->vcf_file;
  if ($vcf_file) {
    $isa->{raw_data_files}{$vcf_file} = {};
  }

  foreach my $genotype ($self->genotypes) {
    $isa->{genotypes} //= ordered_hashref;

    my $genotype_name = $genotype->name;
    $isa->{genotypes}{$genotype_name} = $genotype->as_isatab($study);

    $isa->{raw_data_files}{$genotypes_filename} //= {};
  }

  return $isa;

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
