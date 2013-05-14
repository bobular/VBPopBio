package Bio::Chado::VBPopBio::Result::Linker::ProjectContact;

use base 'Bio::Chado::Schema::Result::Project::ProjectContact';
__PACKAGE__->load_components('+Bio::Chado::VBPopBio::Util::Subclass');
__PACKAGE__->subclass({
		       project => 'Bio::Chado::VBPopBio::Result::Project',
		       contact => 'Bio::Chado::VBPopBio::Result::Contact',
		      });

__PACKAGE__->resultset_attributes({ order_by => 'project_contact_id' });

=head1 NAME

Bio::Chado::VBPopBio::Result::Linker::ProjectContact

=head1 SYNOPSIS

Wrapper class to maintain correct relationships between the VBPopBio objects.  You should not need to use this.

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
