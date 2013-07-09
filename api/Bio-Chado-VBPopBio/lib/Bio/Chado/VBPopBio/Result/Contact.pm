package Bio::Chado::VBPopBio::Result::Contact;

use strict;
use base 'Bio::Chado::Schema::Result::Contact::Contact';
__PACKAGE__->load_components('+Bio::Chado::VBPopBio::Util::Subclass');
__PACKAGE__->subclass({
		       project_contacts => 'Bio::Chado::VBPopBio::Result::Linker::ProjectContact',
		       nd_experiment_contacts => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentContact',
		       type => 'Bio::Chado::VBPopBio::Result::Cvterm',
		      });

=head1 NAME

Bio::Chado::VBPopBio::Result::Contact

=head1 SYNOPSIS

Contact object with extra convenience functions

=head1 MANY-TO-MANY RELATIONSHIPS

=head2 experiments

Type: many_to_many

Returns a resultset of nd_experiments

Related object: Bio::Chado::VBPopBio::Result::Experiment

=cut

__PACKAGE__->many_to_many
    (
     'experiments',
     'nd_experiment_contacts' => 'nd_experiment',
    );

=head2 projects

Type: many_to_many

Returns a list of projects

Related object: Bio::Chado::VBPopBio::Result::Project

=cut

__PACKAGE__->many_to_many
    (
     'projects',
     'project_contacts' => 'project',
    );



=head1 SUBROUTINES/METHODS

=head2 as_data_structure

returns a json-like hashref of arrayrefs and hashrefs

=cut

sub as_data_structure {
  my ($self, $depth) = @_;
  return $self->description,
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

1; # End of Bio::Chado::VBPopBio::Result::Phenotype
