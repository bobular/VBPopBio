package Bio::Chado::VBPopBio::Result::Experiment::PhenotypeAssay;

use base 'Bio::Chado::VBPopBio::Result::Experiment';
__PACKAGE__->load_components(qw/+Bio::Chado::VBPopBio::Util::Subclass/);
__PACKAGE__->subclass({ }); # must call this routine even if not setting up relationships.

=head1 NAME

Bio::Chado::VBPopBio::Result::Experiment::PhenotypeAssay

=head1 SYNOPSIS

Phenotype assay


=head1 SUBROUTINES/METHODS

=head2 special

Do something special for phenotype assay

=cut

sub special {
  my ($self) = @_;
  return 'I am very special';
}

sub as_data_structure {
  my ($self, $depth) = @_;
  $depth = INT_MAX unless (defined $depth);

  return {
	  $self->basic_info,
          # let's only show locations for field_collections at the moment
	  # geolocation => $self->nd_geolocation->as_data_structure,

          phenotypes => "sick?",
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
