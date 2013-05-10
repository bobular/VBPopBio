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
  if (my $protocol = $self->protocols->first) {
    $method = $protocol->type->name;
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
