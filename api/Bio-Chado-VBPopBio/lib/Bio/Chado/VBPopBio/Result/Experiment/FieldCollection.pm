package Bio::Chado::VBPopBio::Result::Experiment::FieldCollection;

use POSIX;
use base 'Bio::Chado::VBPopBio::Result::Experiment';
__PACKAGE__->load_components(qw/+Bio::Chado::VBPopBio::Util::Subclass/);
__PACKAGE__->subclass({ }); # must call this routine even if not setting up relationships.

=head1 NAME

Bio::Chado::VBPopBio::Result::Experiment::FieldCollection

=head1 SYNOPSIS

Field collection


=head1 SUBROUTINES/METHODS

=head2 result_summary

returns a brief HTML summary of the assay results

=cut

sub result_summary {
  my ($self) = @_;
  my $schema = $self->result_source->schema;

  my $method = 'unknown method';
  my @protocols = $self->protocols->all;
  if (@protocols) {
    $method = join ', ', map { $_->type->name } @protocols;
  }

  my $geoloc = $self->geolocation;
  my $collection_site_term = $schema->types->collection_site;
  my ($gazprop) = $geoloc->multiprops($collection_site_term);
  if ($gazprop) {
    my $gazname = $gazprop->cvterms->[1]->name;
    return "$gazname ($method)";
  } else {
    # return a concatenated list of all free-text geoloc multiprops:
    my $textname = join "; ", map $_->value, grep $_->value, $geoloc->multiprops;
    return "$textname ($method)";
  }
}


=head2 as_data_structure

provide data for JSONification

  $data = $assay->as_data_structure($depth)

if $depth is defined and less than or equal to zero, no child objects will be returned

=cut

sub as_data_structure {
  my ($self, $depth) = @_;
  $depth = INT_MAX unless (defined $depth);

  return {
	  $self->basic_info,
	  geolocation => $self->nd_geolocation->as_data_structure,
	 };
}

=head2 geolocation

alias for nd_geolocation

=cut

sub geolocation {
  my ($self, @args) = @_;
  return $self->nd_geolocation(@args);
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
