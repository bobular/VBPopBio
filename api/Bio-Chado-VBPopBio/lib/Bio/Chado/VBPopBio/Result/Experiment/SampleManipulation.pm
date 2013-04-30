package Bio::Chado::VBPopBio::Result::Experiment::SampleManipulation;

use base 'Bio::Chado::VBPopBio::Result::Experiment';
__PACKAGE__->load_components(qw/+Bio::Chado::VBPopBio::Util::Subclass/);
__PACKAGE__->subclass({ }); # must call this routine even if not setting up relationships.

=head1 NAME

Bio::Chado::VBPopBio::Result::Experiment::SampleManipulation

=head1 SYNOPSIS

Sample manipulation "assay"


=head1 SUBROUTINES/METHODS

=head stocks_used

stocks filtered by nd_experiment_stock.type

=cut

sub stocks_used {
  my ($self) = @_;
  my $schema = $self->result_source->schema;
  return $self->search_related('nd_experiment_stocks', { 'me.type_id' => $schema->types->assay_uses_sample->id })->search_related('stock');
}

=head stocks_created

stocks filtered by nd_experiment_stock.type

=cut

sub stocks_created {
  my ($self) = @_;
  my $schema = $self->result_source->schema;
  return $self->search_related('nd_experiment_stocks', { 'me.type_id' => $schema->types->assay_creates_sample->id })->search_related('stock');
}

=head2 as_data_structure

nothing special added here yet.

=cut

sub as_data_structure {
  my ($self, $depth) = @_;
  $depth = INT_MAX unless (defined $depth);

  return {
	  $self->basic_info,
	  type => 'sample manipulation',
	  inputs => [ map { $_->stable_id } $self->stocks_used ],
	  outputs => [ map { $_->stable_id } $self->stocks_created ],
	 };
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
