package Bio::Chado::VBPopBio::Result::Experiment::FieldCollection;

use strict;
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

  my $geoloc_summary = $self->geolocation->summary;
  return "$geoloc_summary ($method)";
}


=head2 as_data_structure

provide data for JSONification

  $data = $assay->as_data_structure($depth)

if $depth is defined and less than or equal to zero, no child objects will be returned

=cut

sub as_data_structure {
  my ($self, $depth) = @_;

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


=head2 as_cytoscape_graph

returns a perl data structure corresponding to Cytoscape JSON format

=cut

sub as_cytoscape_graph {
  my ($self, $nodes, $edges) = @_;

  $nodes //= {};
  $edges //= {};

  my $assay_id = sprintf "assay%08d", $self->id;
  $nodes->{$assay_id} //= { data => {
				     id => $assay_id,
				     name => $self->external_id,
				     type => $self->type->name,
				    } };

  my $geoloc = $self->geolocation;
  my $geoloc_id = sprintf "geoloc%08d", $geoloc->id;
  $nodes->{$geoloc_id} //= { data => {
				      id => $geoloc_id,
				      name => $geoloc->description,
				      type => 'geolocation',
				     } };
  $edges->{"$assay_id:$geoloc_id"} //= { data => {
						  id => "$assay_id:$geoloc_id",
						  source => $assay_id,
						  target => $geoloc_id,
						 } } ;

  my $graph = {
	       elements => {
			    nodes => [ values(%$nodes) ],
			    edges => [ values(%$edges) ],
			   }
	      };

  return $graph;
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
