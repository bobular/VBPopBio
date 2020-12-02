package Bio::Chado::VBPopBio::Result::Experiment::FieldCollection;

use strict;
use base 'Bio::Chado::VBPopBio::Result::Experiment';
__PACKAGE__->load_components(qw/+Bio::Chado::VBPopBio::Util::Subclass/);
__PACKAGE__->subclass({ }); # must call this routine even if not setting up relationships.

use aliased 'Bio::Chado::VBPopBio::Util::Multiprops';

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
    $method = join ', ', sort map { $_->type->name } @protocols;
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


=head2 as_isatab

handles the nd_geolocation data export

=cut

sub as_isatab {
  my ($self, $study, $assay_filename) = @_;

  my $isa = $self->SUPER::as_isatab($study, $assay_filename);

  my $assay_characteristics = $isa->{characteristics};

  my $latitude_heading = 'Collection site latitude (EUPATH:OBI_0001620)';
  my $longitude_heading = 'Collection site longitude (EUPATH:OBI_0001621)';
  my $altitude_heading = 'Collection site altitude (TBD_EUPATH_ONTOLOGY_ISSUE_111)';

  my $geolocation = $self->geolocation;
  $assay_characteristics->{$latitude_heading}{value} = $geolocation->latitude;
  $assay_characteristics->{$longitude_heading}{value} = $geolocation->longitude;
  $assay_characteristics->{$altitude_heading}{value} = $geolocation->altitude;

  my ($geo_comments, $geo_characteristics) = Multiprops->to_isatab($geolocation);
  # fix the names and capitalisation
  # e.g. "Characteristics [city (VBcv:0000844)]" to "Characteristics [Collection site city (VBcv:0000844)]"
  foreach my $old_key (keys %$geo_characteristics) {
    my $new_key = $old_key;
    $new_key = "collection site $new_key" unless ($new_key =~ /collection site/i);
    $new_key = ucfirst($new_key);
    $geo_characteristics->{$new_key} = delete $geo_characteristics->{$old_key};
  }

  # now copy over into the assay's characteristics
  grep { $assay_characteristics->{$_} = $geo_characteristics->{$_} } keys %$geo_characteristics;

  if ($geo_comments && keys %$geo_comments) {
    my $schema = $self->result_source->schema;
    $schema->defer_exception_once("geolocation has comments fields that aren't handled yet");
  }

  # fallback for non-ontology site names
  #### Not needed for VEuPath export ####
  # my $collection_site_heading = 'Collection site (VBcv:VBcv_0000831)';
  # unless ($assay_characteristics->{$collection_site_heading}{value}) {
  #   $assay_characteristics->{$collection_site_heading}{value} = $geolocation->description;
  # }

  # add a catch-all protocol if none present
  unless (keys %{$isa->{protocols}}) {
    my $protocol_key = 'GENERIC_COLLECT';
    my $protocol_isa = $isa->{protocols}{$protocol_key} = {};

    my $already_added_to_investigation_sheet =
      grep { $_->{study_protocol_name} eq $protocol_key }
        @{$study->{study_protocols}};
    unless ($already_added_to_investigation_sheet) {
      push @{$study->{study_protocols}},
	{
	 study_protocol_name => $protocol_key,
	 study_protocol_type => 'arthropod specimen collection process',
	 study_protocol_type_term_source_ref => 'EUPATH',
	 study_protocol_type_term_accession_number => 'EUPATH_0000808',
	 # study_protocol_description => '',
	};
    }
  }

  return $isa;
}


=head2 has_isatab_sheet

returns true if the assay should be represented in ISA-Tab

=cut

sub has_isatab_sheet {
  my $self = shift;
  return 0;
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
