package Bio::Chado::VBPopBio::Result::Experiment::PhenotypeAssay;

use strict;
use base 'Bio::Chado::VBPopBio::Result::Experiment';
__PACKAGE__->load_components(qw/+Bio::Chado::VBPopBio::Util::Subclass/);
__PACKAGE__->subclass({ }); # must call this routine even if not setting up relationships.

use Bio::Chado::VBPopBio::Util::Functions qw/ordered_hashref/;

=head1 NAME

Bio::Chado::VBPopBio::Result::Experiment::PhenotypeAssay

=head1 SYNOPSIS

Phenotype assay


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
    $method = join ', ', map { $_->type->name } @protocols;
  }

  my $text = "no phenotypes";
  my @text;
  my $max_shown = 4;
  my $phenotypes = $self->phenotypes;
  # avoid using resultset->count
  while (my $phenotype = $phenotypes->next) {
    push @text, $phenotype->name;
    if (@text == $max_shown) {
      push @text, sprintf "; and %d more phenotypes", $phenotypes->count - $max_shown;
      last;
    }
  }
  $text = join '; ', @text if (@text);
  return "$text ($method)";
}

=head2 as_data_structure

return data for jsonification

=cut

sub as_data_structure {
  my ($self, $depth) = @_;

  return {
	  $self->basic_info,
          # let's only show locations for field_collections at the moment
          phenotypes => [ map { $_->as_data_structure } $self->phenotypes ],
	 };
}

=head2 delete

deletes the experiment in a cascade which deletes all would-be orphan related objects

=cut

sub delete {
  my $self = shift;

  my $linkers = $self->related_resultset('nd_experiment_phenotypes');
  while (my $linker = $linkers->next) {
    if ($linker->phenotype->experiments->count == 1) {
      $linker->phenotype->delete;
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

  foreach my $phenotype ($self->phenotypes) {
    my $phenotype_id = sprintf "phenotype%08d", $phenotype->id;
    $nodes->{$phenotype_id} //= { data => {
					id => $phenotype_id,
					name => $phenotype->name,
					type => 'phenotype',
				       } };
    $edges->{"$assay_id:$phenotype_id"} //= { data => {
						    id => "$assay_id:$phenotype_id",
						    source => $assay_id,
						    target => $phenotype_id,
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

handles the p_phenotype file export

=cut

sub as_isatab {
  my ($self, $study, $assay_filename) = @_;

  my $isa = $self->SUPER::as_isatab($study, $assay_filename);

  my $phenotypes_filename = $assay_filename;
  $phenotypes_filename =~ s/^a_/p_/;

  foreach my $phenotype ($self->phenotypes) {
    $isa->{phenotypes} //= ordered_hashref;

    my $phenotype_name = $phenotype->name;
    $isa->{phenotypes}{$phenotype_name} = $phenotype->as_isatab();

    $isa->{raw_data_files}{$phenotypes_filename} //= {};
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
