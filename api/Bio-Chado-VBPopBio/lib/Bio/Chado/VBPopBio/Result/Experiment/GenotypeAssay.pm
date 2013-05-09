package Bio::Chado::VBPopBio::Result::Experiment::GenotypeAssay;

use base 'Bio::Chado::VBPopBio::Result::Experiment';
__PACKAGE__->load_components(qw/+Bio::Chado::VBPopBio::Util::Subclass/);
__PACKAGE__->subclass({ }); # must call this routine even if not setting up relationships.

use aliased 'Bio::Chado::VBPopBio::Util::Extra';

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
  if ($self->protocols->count) {
    $method = $self->protocols->first->type->name;
  }

  my $max_shown = 4;
  my $ngenotypes = $self->genotypes->count;
  # but just get the first three
  my @genotypes = $self->genotypes->slice(0,$max_shown-1);
  my $text = join "; ", map { $_->description || $_->name } @genotypes;
  if ($ngenotypes > $max_shown) {
    $text .= sprintf "; and %d more genotypes", $ngenotypes-$max_shown;
  }
  if ($ngenotypes == 0 && $self->vcf_file) {
    $text = "variants shown in genome browser";
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

=head2 as_data_structure

return a data structure for jsonification

=cut

sub as_data_structure {
  my ($self, $depth) = @_;
  $depth = INT_MAX unless (defined $depth);

  return {
      $self->basic_info,
      genotypes => [ map { $_->as_data_structure } $self->genotypes->all ],
      vcf_file => $self->vcf_file,
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
