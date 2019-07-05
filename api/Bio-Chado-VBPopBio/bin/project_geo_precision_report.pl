#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: bin/project_geo_precision_report.pl --project VBP0000nnn
#
#        also allows comma-separated project IDs.
#
# DOESN'T CHANGE THE DATABASE - it's read-only
#

use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use Getopt::Long;
use utf8::all;

use aliased 'Bio::Chado::VBPopBio::Util::Multiprop';

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $samples = $schema->stocks;
my $cvterms = $schema->cvterms;
my $projects = $schema->projects;
my $project_ids;
my $limit;

# if this matches the comment type/heading
# e.g. Comment [collection site coordinates]
# then the comment will processed into ontology-based qualifiers
my $comment_regexp = qr/\bcollection site coordinates\b/;


GetOptions("projects=s"=>\$project_ids,
           "limit=i"=>\$limit, # just process N collections per project
	  );


die "must provide value for option --project\n" unless ($project_ids);

$| = 1;




$schema->txn_do_deferred
  ( sub {

      my %lat_counts;  # 2 => 123, 3 => 345
      my %long_counts; # etc (where 2 and 3 are the number of decimal places)

      my %seen_locations; # nd_geolocation id => 1

      foreach my $project_id (split /\W+/, $project_ids) {
	my $project = $schema->projects->find_by_stable_id($project_id);
	unless ($project) {
	  $schema->defer_exception("project '$project_id' not found");
	  next;
	}
        my $done = 0;
        my $todo = $project->field_collections->count();
        my $project_name = $project->name;
	warn "processing unique geolocations from $project_id - $project_name\n";

	foreach my $collection ($project->field_collections) {

          my $location = $collection->nd_geolocation;

          next if ($seen_locations{$location->id}++);

          my ($lat, $long) = ($location->latitude, $location->longitude);
          if (defined $lat && defined $long) {
            my $lat_dp = length($1) if ($lat =~ /\.(\d+)/);
            my $long_dp = length($1) if ($long =~ /\.(\d+)/);
            $lat_counts{$lat_dp // 0}++;
            $long_counts{$long_dp // 0}++;
          }

          last if ($limit && $done >= $limit);
	}
      }

      print "\nDecimal places reports:\n\n";
      foreach my $dp (sort { $a <=> $b } keys %lat_counts) {
        print "Latitude  $dp decimal places: $lat_counts{$dp}\n";
      }
      print "\n";
      foreach my $dp (sort { $a <=> $b } keys %long_counts) {
        print "Longitude $dp decimal places: $long_counts{$dp}\n";
      }

    } );

