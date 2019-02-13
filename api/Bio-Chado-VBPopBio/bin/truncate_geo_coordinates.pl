#!/usr/bin/env perl
#                 -*- mode: cperl -*-
#
# usage: bin/truncate_gps_coordinates.pl --project VBP0000nnn --format %.2f
#
# comma-separated projects also allowed
#
# options:
#
# --dry-run
# --dbname dbname
# --dbuser dbuser
#
#
# will go through all geolocations of all collections in the project and reformat the latitude and longitude
# values in a completely irreversible manner (other than reloading an old database of course)
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

my $dbname = $ENV{CHADO_DB_NAME};
my $dbuser = $ENV{USER};
my $dry_run;
my $format;
my $project_ids;

GetOptions("dbname=s"=>\$dbname,
	   "dbuser=s"=>\$dbuser,
	   "dry-run|dryrun"=>\$dry_run,
	   "projects=s"=>\$project_ids,
	   "format=s"=>\$format,
	  );


die "must provide --format and --project args\n" unless ($format && $project_ids);

my $dsn = "dbi:Pg:dbname=$dbname";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $dbuser, undef, { AutoCommit => 1 });
# the next line is for extra speed - but check for identical results with/without
$schema->storage->_use_join_optimizer(0);
my $stocks = $schema->stocks;

# should speed things up
$schema->storage->_use_join_optimizer(0);

$schema->txn_do_deferred
  ( sub {
      foreach my $project_id (split /\W+/, $project_ids) {

        my $project = $schema->projects->find_by_stable_id($project_id);
        unless ($project) {
          $schema->defer_exception("not a valid project ID '$project_id'");
          next;
        }

        warn "processing ".$project->name."...\n";

        my $collections = $project->field_collections;

        while (my $collection = $collections->next) {
          my $geolocation = $collection->geolocation;
          if ($geolocation) {
            my $latitude = $geolocation->latitude;
            my $longitude = $geolocation->longitude;
            if (looks_like_number($latitude) && looks_like_number($longitude)) {
              $geolocation->latitude(sprintf $format, $latitude);
              $geolocation->longitude(sprintf $format, $longitude);
              $geolocation->update;
            }
          }
        }
      }

      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );


