#!/usr/bin/env perl
#                 -*- mode: cperl -*-
#
# usage: bin/truncate_gps_coordinates.pl --project VBP0000nnn --format %.2f
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
#my $project_id;

GetOptions("dbname=s"=>\$dbname,
	   "dbuser=s"=>\$dbuser,
	   "dry-run|dryrun"=>\$dry_run,
#	   "project=s"=>\$project_id,
	  );


#die "must provide --project args\n" unless ($project_id);

my $dsn = "dbi:Pg:dbname=$dbname";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $dbuser, undef, { AutoCommit => 1 });
# the next line is for extra speed - but check for identical results with/without
$schema->storage->_use_join_optimizer(0);
my $stocks = $schema->stocks;
# my $project = $schema->projects->find_by_stable_id($project_id);
my $projects = $schema->projects;

# die "not a valid project ID '$project_id'\n" unless ($project);
# warn "processing ".$project->name."...\n";

# should speed things up
$schema->storage->_use_join_optimizer(0);


my $start_date_term = $schema->types->start_date;
my $end_date_term = $schema->types->end_date;


$schema->txn_do_deferred
  ( sub {

     while (my $project = $projects->next) {
      my $project_id = $project->stable_id;
      my $collections = $project->field_collections;

      while (my $collection = $collections->next) {
	my ($start_date_prop) = $collection->multiprops($start_date_term);
	my ($end_date_prop) = $collection->multiprops($end_date_term);
	if (defined $start_date_prop && defined $end_date_prop) {
	  my $end_date = $end_date_prop->value;
	  my $start_date = $start_date_prop->value;
	  if ($end_date lt $start_date) {
	    print "$project_id problem with $start_date / $end_date\n";
	  }

	}

      }

      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    }
   } );


