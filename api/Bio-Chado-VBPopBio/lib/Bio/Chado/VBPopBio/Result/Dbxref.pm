package Bio::Chado::VBPopBio::Result::Dbxref;

use base 'Bio::Chado::Schema::Result::General::Dbxref';
__PACKAGE__->load_components('+Bio::Chado::VBPopBio::Util::Subclass');
__PACKAGE__->subclass({
		       cvterm => 'Bio::Chado::VBPopBio::Result::Cvterm',
		       dbxrefprops => 'Bio::Chado::VBPopBio::Result::Dbxrefprop',
		       stocks => 'Bio::Chado::VBPopBio::Result::Stock',
		       nd_experiment_dbxrefs => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentDbxref',
		       cvterm_dbxrefs => 'Bio::Chado::VBPopBio::Result::Linker::CvtermDbxref',
		       #
		       # MORE relationships need to be added here
		       #
		      });

=head1 NAME

Bio::Chado::VBPopBio::Result::Dbxref

=head1 SYNOPSIS

General::Dbxref object with extra convenience functions

We have to wrap this so that $dbxref->cvterm brings back "one of ours".

=head1 SUBROUTINES/METHODS

=head2 as_string

returns db.name:accession, e.g. MIRO:0012345

=cut

sub as_string {
  my $self = shift;
  return $self->db->name().':'.$self->accession(),
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

1; # End of Bio::Chado::VBPopBio::Result::Dbxref
