#!/usr/bin/env perl
#                 -*- mode: cperl -*-
#
# usage: bin/geocode_projects.pl --projects VBP0000nnn,VBP0000mmm
#
# or, if you want to geocode the entire database
#
#        bin/geocode_projects.pl --projects ALL
#
#
# Be aware that any geolocation used by several projects A,B,C will be modified if
# this script is only run on project C.
#
# options:
#
# --dry-run
# --gadm-stem ../../../gadm-processing/gadm36       # location of gadmVV_N.{shp,dbf,...} files ("shapefile")
#
# requires that the GADM-based VBGEO ontology is already loaded, see
# https://github.com/bobular/GADM-to-OBO
# and
# https://confluence.vectorbase.org/display/SOPs/PopBio+Chado+db+maintenance#PopBioChadodbmaintenance-GADM(wasGAZ)
#
#
# DESCRIPTION
#
# This will go through all geolocations of all collections in the project(s) and do the following:
#
# First remove all "Characteristics [Collection site *]" characteristics and the
# "Characteristics [Collection site]" term (formerly stored GAZ term here)
#
# Using the lat/long coordinates it will look to see if this point is within any
# of the "level 0" GADM polygons.
#
# If it is in one and one only polygon, this will be the country.  The English name
# will be added to "Characteristics [Collection site country (VBcv:0000701)] as free text
#
# If not then report an error and go to the next geolocation
#
# Set the "Characteristics [Collection site]" term to the country VBGEO TERM
#
# Then it will check all the polygons in level 1 that are children of the level 0 term
# and if there's a single match set it as "Characteristics [Collection ADM1 (VBcv:0001129)]"
# as free text.  Also overwrite "Characteristics [Collection site]" with this more fine-grained VBGEO term.
#
# Repeat previous step for level 2 (but storing as "Characteristics [Collection ADM2 (VBcv:0001130)]")
#

use strict;
use warnings;
use feature 'switch';
use lib 'lib';
use Getopt::Long;
use Bio::Chado::VBPopBio;
use Scalar::Util qw(looks_like_number);
use List::MoreUtils;
use utf8::all;
use Geo::ShapeFile;

my $dbname = $ENV{CHADO_DB_NAME};
my $dbuser = $ENV{USER};
my $dry_run = 1;
my $gadm_stem = '../../../gadm-processing/gadm36';
my $project_ids;

GetOptions("dry-run|dryrun"=>\$dry_run,
	   "projects=s"=>\$project_ids,
           "gadm_stem|gadm-stem=s"=>\$gadm_stem,
	  );


my $dsn = "dbi:Pg:dbname=$dbname";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $dbuser, undef, { AutoCommit => 1 });
# the next line is for extra speed - but check for identical results with/without
$schema->storage->_use_join_optimizer(0);
my $projects = $schema->projects;
my $cvterms = $schema->cvterms;

my $anthropogenic_descriptor_term = $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0000834' }) || die;
my $collection_site_term = $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0000831' }) || die;
my $country_term = $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0000701' }) || die;
#my $adm1_term = $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001129' }) || die;
#my $adm2_term = $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001130' }) || die;

#
# initialise the shapefiles
#

my @shapefile;
foreach my $level (0 .. 2) {
  $shapefile[$level] = Geo::ShapeFile->new(join '_', $gadm_stem, $level);
}


# should speed things up
$schema->storage->_use_join_optimizer(0);

$schema->txn_do_deferred
  ( sub {
      foreach my $project_id (split /\W+/, $project_ids) {

        my $collections;

        if (lc($project_id) ne 'all') {

          my $project = $projects->find_by_stable_id($project_id);
          unless ($project) {
            $schema->defer_exception("not a valid project ID '$project_id'");
            next;
          }
          warn "processing ".$project->name."...\n";
          $collections = $project->field_collections;
        } else {
          $collections = $schema->field_collections;
          warn "processing ALL field collections...\n";
        }


        while (my $collection = $collections->next) {
          my $geolocation = $collection->geolocation;
          if ($geolocation) {
            my $latitude = $geolocation->latitude;
            my $longitude = $geolocation->longitude;
            if (looks_like_number($latitude) && looks_like_number($longitude)) {
              my $lat = $geolocation->latitude;
              my $long = $geolocation->longitude;

              print "Processing ( $lat , $long )\n";

              # remove existing props
              foreach my $multiprop ($geolocation->multiprops) {
                my ($mprop_type) = $multiprop->cvterms;
                if ($mprop_type->id == $collection_site_term->id ||
                    $anthropogenic_descriptor_term->has_child($mprop_type)) {
                  warn "Removing property : ".$multiprop->as_string."\n";
                  $geolocation->delete_multiprop($multiprop);
                }
              }

              # do the geocoding lookup
              my $best_term; # the finest-grain VBGEO term we can find

              my $num_shapes = $shapefile[0]->shapes;
              my $query_point = Geo::ShapeFile::Point->new(X => $long, Y => $lat);
              my @found_indices;
              foreach my $index (1 .. $num_shapes) {
                my $shape = $shapefile[0]->get_shp_record($index);
                if ($shape->contains_point($query_point)) {
                  push @found_indices, $index;
                }
              }
              if (@found_indices == 1) {
                my $index = shift @found_indices;
                my $dbf = $shapefile[0]->get_dbf_record($index);
                my $gadm_id = $dbf->{GID_0};
                my $country_name = $dbf->{NAME_0};
                my $gadm_term = $cvterms->find_by_accession({ term_source_ref => 'GADM',
                                                              term_accession_number => $gadm_id,
                                                              prefered_term_source_ref => 'VBGEO' });
                die "FATAL couldn't find VBGEO term for $country_name\n" unless (defined $gadm_term);

                warn "Adding country term : $country_name\n";
                my $country_prop = Multiprop->new(cvterms=>[ $country_term ], value => $country_name);
                $geolocation->add_multiprop($country_prop);

              } else {
                # warning time...
                my @projects = $collection->projects->all;
                my $fc_id = $collection->stable_id;

                if (@found_indices == 0) {
                  warn "WARNING: no country found for ( $lat, $long ) from $fc_id of @projects\n";
                } else {
                  warn "WARNING: multiple countries found for ( $lat, $long ) from $fc_id of @projects\n";
                }
              }
            }
          }
        }
      }

      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );


