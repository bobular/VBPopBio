#!/usr/bin/env perl
# -*- mode: cperl -*-
#
# makes a metaproject of all samples from a collection within the GAZ
# term area, with geo-coordinates, whose species is unambiguously determined to
# be a child of the provided species term
#
#
#
# usage: bin/make_metaproject_species_gaz_geo.pl -external_id META-Anopheles-Mali -species MIRO:40003480 -gaz GAZ:00000584 -release VB-2013-08
#
# options:
#   --projects VBP0000005,VBP0000003 : recommended list of projects to trawl through
#   --dry-run              : rolls back transaction and doesn't insert into db permanently
#   --limit 50             : only process first 50 samples (DOES NOT IMPLY --dry-run)
#   --delete               : deletes project with external ID (first argument, e.g. META-Anopheles-Cameroon)
#
#

use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use JSON;
use Getopt::Long;


my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $projects = $schema->projects;
my $metaprojects = $schema->metaprojects;
my $dry_run;
#my $json_file;
my $json = JSON->new->pretty;
my $samples_file;
my $limit;
my $delete;
my ($external_id, $species_accession, $gaz_accession, $release, $project_ids);


GetOptions("dry-run|dryrun"=>\$dry_run,
#	   "json=s"=>\$json_file,
	   "limit=i"=>\$limit,
	   "delete"=>\$delete, # NOT THE SAME AS load_project
	   "external_id=s"=>\$external_id,
	   "gaz_term=s"=>\$gaz_accession,
	   "species_term=s"=>\$species_accession,
	   "release=s"=>\$release,
	   "projects=s"=>\$project_ids,
	  );

# $dry_run = 1 if ($limit);

die "--external_id option required" unless ($external_id);
die "--gaz_term option required" unless ($gaz_accession);
die "--species_term option required" unless ($species_accession);
die "--release option required" unless ($release);

if ($project_ids) {
  my @project_ids = split /,/, $project_ids;
  if (@project_ids) {
    $projects->set_cache([ map { $projects->find_by_stable_id($_) } @project_ids ]);
  }
} else {
  warn "warning: could take a LONG time going through ALL projects - consider the --projects option\n";
}

my $cvterms = $schema->cvterms;
my ($species_onto, $species_acc) = split /:/, $species_accession;
my $species_term = $cvterms->find_by_accession({ term_source_ref => $species_onto,
						 term_accession_number => $species_acc,
						 prefered_term_source_ref => 'VBsp',
					       });
my ($gaz_onto, $gaz_acc) = split /:/, $gaz_accession;
my $gaz_term = $cvterms->find_by_accession({ term_source_ref => $gaz_onto,
					     term_accession_number => $gaz_acc,
					   });
# warn "species accession is ".$species_term->dbxref->as_string."\n";

die "bad args @ARGV (should be species and GAZ ontology accessions)\n" unless (defined $gaz_term && defined $species_term);

my $name = "Meta-project: all mappable ".$species_term->name." collected in ".$gaz_term->name." (made for release $release)";
my $description = "This project contains samples and assays from other projects.";

warn "starting to process samples and assays for metaproject\nname: $name\ndescription: $description\n";

my @stocks;
my @assays;
my @projects;
my %used_project_ids;
my $collection_site_type = $schema->types->collection_site;
my $unambiguous = $schema->types->unambiguous;

# go through all stocks (of all/some projects)
while (my $project = $projects->next) {
  my $project_stocks = $project->stocks;
  my $count = 0;
  while (my $stock = $project_stocks->next) {
    my $fc = $stock->field_collections->first;
    if ($fc) {
      my $geoloc = $fc->geolocation;
      if ($geoloc->latitude || $geoloc->longitude) {
	my (@gazprops) = $geoloc->multiprops($collection_site_type);
	if (@gazprops == 1) {
	  my $stock_gaz_term = $gazprops[0]->cvterms->[1];
	  if ($gaz_term->id == $stock_gaz_term->id ||
	      $gaz_term->has_child($stock_gaz_term)) {
	    my ($best_species, $status) = $stock->best_species($project);
	    if ($status->id == $unambiguous->id &&
		($best_species->id == $species_term->id ||
		 $species_term->has_child($best_species))) {
	      warn "selected sample ".$stock->name."\n";
	      push @stocks, $stock;
	      push @assays, $fc, $stock->species_identification_assays->all;
	      push @projects, $project unless ($used_project_ids{$project->id}++);
	      $count++;
	    }
	  }
	}
      }
    }
    last if (defined $limit && $count >= $limit);
  }
}


my $stocks = $schema->stocks;
$stocks->set_cache(\@stocks);

my $assays = $schema->experiments;
$assays->set_cache(\@assays);

$projects = $schema->projects;
$projects->set_cache(\@projects);

print "num stocks ".$stocks->count."\n";
print "num assays ".$assays->count."\n";
print "num projects ".$projects->count."\n";

$schema->txn_do_deferred
  ( sub {

      my $existing = $projects->find_by_external_id($external_id);
      if ($existing) {
	if ($delete) {
	  warn "deleting existing...\n";
	  $existing->delete;
	  warn "delete done\n";
	} else {
	  $schema->defer_exception("project already exists but you didn't specify the --delete option");
	  return;
	}
      }

      my $metaproject = $metaprojects->create_with
	({ name => $name,
	   description => $description,
	   external_id => $external_id,
	   stocks => $stocks,
	   assays => $assays,
	   projects => $projects,
	  });

      print "metaproject's stable id is ".$metaproject->stable_id."\n";
      print "metaproject has ".$metaproject->stocks->count." samples\n";
      print "metaproject has ".$metaproject->experiments->count." assays\n";
      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );

