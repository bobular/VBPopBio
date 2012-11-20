package Bio::Chado::VBPopBio::Result::Protocol;

use strict;
use Carp;
use feature 'switch';
use base 'Bio::Chado::Schema::Result::NaturalDiversity::NdProtocol';
__PACKAGE__->load_components(qw/+Bio::Chado::VBPopBio::Util::Subclass/);
__PACKAGE__->subclass({ nd_experiment_protocols => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentProtocol',
		        nd_protocolprops => 'Bio::Chado::VBPopBio::Result::Protocolprop',
			type => 'Bio::Chado::VBPopBio::Result::Cvterm',
		      });

=head1 NAME

Bio::Chado::VBPopBio::Result::Protocol

=head1 SYNOPSIS

Protocol object with extra convenience functions.
Specialised experiment classes can be found in the.
Bio::Chado::VBPopBio::Result::Experiment::* namespace.


=head1 SUBROUTINES/METHODS

=head1 AUTHOR

VectorBase, C<< <info at vectorbase.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 VectorBase.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Bio::Chado::VBPopBio::Result::Protocol
