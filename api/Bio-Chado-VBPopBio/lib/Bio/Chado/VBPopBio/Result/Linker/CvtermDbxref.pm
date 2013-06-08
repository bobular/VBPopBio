package Bio::Chado::VBPopBio::Result::Linker::CvtermDbxref;

use base 'Bio::Chado::Schema::Result::Cv::CvtermDbxref';
__PACKAGE__->load_components('+Bio::Chado::VBPopBio::Util::Subclass');
__PACKAGE__->subclass({
		       cvterm => 'Bio::Chado::VBPopBio::Result::Cvterm',
		       dbxref => 'Bio::Chado::VBPopBio::Result::Dbxref',
		      });

=head1 NAME

Bio::Chado::VBPopBio::Result::Linker::CvtermDbxref

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
