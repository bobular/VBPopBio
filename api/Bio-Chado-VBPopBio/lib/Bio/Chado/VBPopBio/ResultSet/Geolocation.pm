package Bio::Chado::VBPopBio::ResultSet::Geolocation;

use base 'DBIx::Class::ResultSet';
use Carp;
use aliased 'Bio::Chado::VBPopBio::Util::Multiprops';
use Tie::Hash::Indexed;

=head1 NAME

Bio::Chado::VBPopBio::ResultSet::Geolocation

=head1 SYNOPSIS

Re-branded NdGeolocation object


=head1 SUBROUTINES/METHODS

=head2 find_or_create_from_isatab

Create a gelocation object and attach necessary properties.
HAS SIDE-EFFECTS of removing location-specific characteristics from isa-tab data structure.

 Usage: $geolocations->find_or_create_from_isatab($isatab_assay_data);

 Desc: This method creates a stock object from the isatab sample hashref (from a field collection assay)
 Ret : a new Experiment::FieldCollection row (is a NdExperiment)
 Args: hashref $isa->{studies}[N]{study_assay_lookup}{'field collection'}{samples}{SAMPLE_ID}
       (example contents below)
         {
           characteristics => { 'Collection site' => { value => 'Kela',
                                                       term_accession_number => 123,
                                                       term_source_ref => 'GAZ' } },
         }

=cut

sub find_or_create_from_isatab {
  my ($self, $assay_data) = @_;
  my $schema = $self->result_source->schema;

  # create the nd_experiment and stock linker type
  my $cvterms = $schema->cvterms;

  my $collection_site_heading = 'Collection site (VBcv:0000831)';
  my $latitude_heading = 'Collection site latitude (VBcv:0000817)';
  my $longitude_heading = 'Collection site longitude (VBcv:0000816)';
  my $altitude_heading = 'Collection site altitude (VBcv:0000832)';

  # note that if any value provided to find_or_new is null,
  # then a new record will be created
  # (this seems reasonable though)
  my $geolocation =
    $self->find_or_new({
			description => $assay_data->{characteristics}{$collection_site_heading}{value} || undef,
			latitude => $assay_data->{characteristics}{$latitude_heading}{value} || undef,
			longitude => $assay_data->{characteristics}{$longitude_heading}{value} || undef,
			altitude => $assay_data->{characteristics}{$altitude_heading}{value} || undef,
			geodetic_datum => 'WGS 84',
		       });

  delete $assay_data->{characteristics}{$latitude_heading};
  delete $assay_data->{characteristics}{$longitude_heading};
  delete $assay_data->{characteristics}{$altitude_heading};
  # delete "Collection site" characteristic if it doesn't contain ontology data
  # we only want to store a multiprop with second GAZ term
  delete $assay_data->{characteristics}{$collection_site_heading}
    unless ($assay_data->{characteristics}{$collection_site_heading}{term_source_ref} &&
	    $assay_data->{characteristics}{$collection_site_heading}{term_accession_number});

  # now copy the relevant remaining characteristics into a new data structure
  my $location_characteristics = ordered_hashref();
  foreach my $cname (keys %{$assay_data->{characteristics}}) {
    # perhaps replace this with cvterm parent test instead!
    # have to decide what to do with household ID!
    if ($cname =~ /collection site/i) {
      $location_characteristics->{$cname} = delete $assay_data->{characteristics}{$cname};
    }
  }
  # now add some props to geolocation unless we already pulled it from the db.
  # this means that the first time you create a geolocation (with no NULL values, see above)
  # you'd better get all its props correct (potentially between projects)
  # An alternative would be to include the assay or project stable_id in the description
  # so that geolocations were only "shared" within a project not between
  unless ($geolocation->in_storage) {
    $geolocation->insert;

    # now add these as multiprops to the geolocation
    Multiprops->add_multiprops_from_isatab_characteristics
      ( row => $geolocation,
	prop_relation_name => 'nd_geolocationprops',
	characteristics => $location_characteristics,
      );
  }

  return $geolocation;
}

=head2 ordered_hashref

Wrapper for Tie::Hash::Indexed - returns a hashref which has already been tied to Tie::Hash::Indexed

no args.

usage: $foo->{bar} = ordered_hashref();  $foo->{bar}{hello} = 123;

=cut

sub ordered_hashref {
  my $ref = {};
  tie %{$ref}, 'Tie::Hash::Indexed';
  return $ref;
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
