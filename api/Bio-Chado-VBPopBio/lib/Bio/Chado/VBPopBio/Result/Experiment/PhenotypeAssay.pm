package Bio::Chado::VBPopBio::Result::Experiment::PhenotypeAssay;

use base 'Bio::Chado::VBPopBio::Result::Experiment';
__PACKAGE__->load_components(qw/+Bio::Chado::VBPopBio::Util::Subclass/);
__PACKAGE__->subclass({ }); # must call this routine even if not setting up relationships.

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
  if ($self->protocols->count) {
    $method = $self->protocols->first->type->name;
  }

  my $max_shown = 4;
  my $nphenotypes = $self->phenotypes->count;
  # but just get the first three
  my @phenotypes = $self->phenotypes->slice(0,$max_shown-1);
  my $text = join "; ", map { $_->name } @phenotypes;
  if ($nphenotypes > $max_shown) {
    $text .= sprintf "; and %d more phenotypes", $nphenotypes-$max_shown;
  }
  return "$text ($method)";
}

=head2 as_data_structure

return data for jsonification

=cut

sub as_data_structure {
  my ($self, $depth) = @_;
  $depth = INT_MAX unless (defined $depth);

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
