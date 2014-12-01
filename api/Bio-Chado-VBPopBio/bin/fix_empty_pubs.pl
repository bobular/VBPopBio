#!/usr/bin/env perl
# -*- mode: cperl -*-
#
# finds projects' publications which have no pubmed_id and no DOI and status="published"
# and fixes their status to "in preparation"
#
#
# usage: CHADO_DB_NAME=my_chado_instance bin/fix_empty_pubs.pl [--dry-run]
#
# options:
#   --dry-run              : rolls back transaction and doesn't insert into db permanently
#   --limit 50             : only process first 50 samples (--dry-run implied)
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
my $dry_run;
my $json_file;
my $json = JSON->new->pretty;
my $samples_file;
my $limit;
my $delete_project;

GetOptions("dry-run|dryrun"=>\$dry_run,
	   "json=s"=>\$json_file,
	   "limit=i"=>\$limit,
	  );

$dry_run = 1 if ($limit);

my ($isatab_dir) = @ARGV;

# should speed things up
$schema->storage->_use_join_optimizer(0);

my $in_preparation_id = $schema->types->in_preparation->id;
my $published_id = $schema->types->published->id;

$schema->txn_do_deferred
  ( sub {

      my $count = 0;
      my $projects = $schema->projects;

      while (my $project = $projects->next) {
	my $stable_id = $project->stable_id;
	printf "checking $stable_id %s\n", $project->name;
	my $done_something = 0;
	foreach my $pub ($project->publications->all) {

	  if (not $pub->pubmed_id and not $pub->doi and $pub->type_id == $published_id) {
	    $pub->update({ type_id => $in_preparation_id });
	    $done_something++;
	  }

	}
	if ($done_something) {
	  $project->update_modification_date();
	  print "made $done_something changes\n";
	}
	last if ($limit && ++$count >= $limit);
      }

      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );

