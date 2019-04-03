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
# --verbose                                         # extra progress output
# --quiet                                           # no progress output, but geocoding failure warnings will still be emitted
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
use aliased 'Bio::Chado::VBPopBio::Util::Multiprop';
use Encode;
use Encode::Detect::Detector;

my $dbname = $ENV{CHADO_DB_NAME};
my $dbuser = $ENV{USER};
my $dry_run = 1;
my $gadm_stem = '../../../gadm-processing/gadm36';
my $project_ids;
my $verbose = 1;
my $quiet;

GetOptions("dry-run|dryrun"=>\$dry_run,
	   "projects=s"=>\$project_ids,
           "gadm_stem|gadm-stem=s"=>\$gadm_stem,
           "verbose"=>\$verbose,  # extra progress output to stderr
           "quiet"=>\$quiet,      # no progress output to stderr
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
my $adm1_term = $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001129' }) || die;
my $adm2_term = $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001130' }) || die;

#
# initialise the shapefiles
#

my @shapefile;
foreach my $level (0 .. 2) {
  $shapefile[$level] = Geo::ShapeFile->new(join '_', $gadm_stem, $level);
}

my @level_terms = ( $country_term, $adm1_term, $adm2_term );
my %seen_geolocation; # id => 1


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
          warn "Processing project : ".$project->name."...\n" unless $quiet;
          $collections = $project->field_collections;
        } else {
          $collections = $schema->field_collections;
          warn "Processing ALL field collections...\n" unless $quiet;
        }

        my $num_collections = $collections->count;
        my $num_done = 0;

        while (my $collection = $collections->next) {
          $num_done++;
          my $collection_id = $collection->stable_id;
          my $geolocation = $collection->geolocation;
          if ($geolocation) {
            next if ($seen_geolocation{$geolocation->id}++);  # only process each geolocation once
            my $latitude = $geolocation->latitude;
            my $longitude = $geolocation->longitude;
            if (looks_like_number($latitude) && looks_like_number($longitude)) {
              my $lat = $geolocation->latitude;
              my $long = $geolocation->longitude;

              warn sprintf("\nProcessing collection %s (%d of %d)\nGeolocation ( %s , %s )\n",
                           $collection_id, $num_done, $num_collections, $lat, $long) unless $quiet;

              # remove existing props
              foreach my $multiprop ($geolocation->multiprops) {
                my ($mprop_type) = $multiprop->cvterms;
                if ($mprop_type->id == $collection_site_term->id ||
                    $anthropogenic_descriptor_term->has_child($mprop_type)) {
                  warn "Removing old property : ".$multiprop->as_string."\n" if $verbose;
                  $geolocation->delete_multiprop($multiprop);
                }
              }

              # do the geocoding lookup
              my $query_point = Geo::ShapeFile::Point->new(X => $long, Y => $lat);
              my $best_geo_term; # the finest-grained VBGEO term we can find for "collection site" property
              my $parent_id;      # the ID, e.g. AFG of the higher level term that was geocoded

              foreach my $level (0 .. 2) {
                last if ($level > 0 && !defined $parent_id);
                # warn "Scanning level $level\n" if $verbose;
                my $shapefile = $shapefile[$level];
                my $num_shapes = $shapefile->shapes;
                my @found_indices;
                foreach my $index (1 .. $num_shapes) {
                  if ($level == 0 || is_child_of_previous($index, $shapefile, $parent_id, $level-1)) {
                    my $shape = $shapefile->get_shp_record($index);
                    if ($shape->contains_point($query_point)) {
                      push @found_indices, $index;
                    }
                  }
                }
                if (@found_indices == 1) {
                  my $index = shift @found_indices;
                  my $dbf = $shapefile->get_dbf_record($index);
                  my $gadm_id = $dbf->{"GID_$level"};
                  my $gadm_name = cleanup($dbf->{"NAME_$level"});
                  my $gadm_term = $cvterms->find_by_accession({ term_source_ref => 'GADM',
                                                                term_accession_number => $gadm_id,
                                                                prefered_term_source_ref => 'VBGEO' });
                  die "FATAL couldn't find VBGEO term for $gadm_name\n" unless (defined $gadm_term);

                  $parent_id = $gadm_id;
                  $best_geo_term = $gadm_term;

                  warn sprintf("Adding free text %s property : %s\n", $level_terms[$level]->name, $gadm_name) unless $quiet;
                  my $peachy_prop = Multiprop->new(cvterms=>[ $level_terms[$level] ], value => $gadm_name);
                  $geolocation->add_multiprop($peachy_prop); # legacy from the "peach coloured" free text columns in ISA-Tab

                } elsif ($level == 0) {
                  # warnings at country level only...
                  my @projects = map { $_->stable_id } $collection->projects->all;
                  my $fc_id = $collection->stable_id;

                  if (@found_indices == 0) {
                    warn "WARNING: no country found for $collection_id ( $lat, $long ) from $fc_id of @projects\n";
                  } else {
                    warn "WARNING: multiple countries found for $collection_id ( $lat, $long ) from $fc_id of @projects\n";
                  }
                }
              }
              if ($best_geo_term) {
                warn sprintf("Adding ontology-based collection site property : %s (%s)\n", $best_geo_term->name, $best_geo_term->dbxref->as_string) unless $quiet;
                my $site_prop = Multiprop->new(cvterms=>[ $collection_site_term, $best_geo_term ]);
                $geolocation->add_multiprop($site_prop);
              }
            }
          }
        }
      }

      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );



sub is_child_of_previous {
  my ($index, $shapefile, $parent_id, $level) = @_;
  my $dbf = $shapefile->get_dbf_record($index);
  return $dbf->{"GID_$level"} eq $parent_id;
}


# fix some issues with encodings and whitespace in place names

sub cleanup {
  my $string = shift;
  my $charset = detect($string);
  if ($charset) {
    # if anything non-standard, use UTF-8
    $string = decode("UTF-8", $string);
  }
  # remove leading and trailing whitespace
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  # fix any newlines or tabs with this
  $string =~ s/\s+/ /g;
  return $string;
}

