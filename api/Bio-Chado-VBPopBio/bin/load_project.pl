#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: CHADO_DB_NAME=my_chado_instance bin/load_project.pl ../path/to/ISA-Tab-directory
#
# options:
#   --dry-run              : rolls back transaction and doesn't insert into db permanently
#   --json filename        : prints pretty JSON for the whole project to the file
#   --sample-info filename : prints sample external ids, stable ids, and comments to TSV
#   --limit 50             : only process first 50 samples (--dry-run implied)
#   --graph-file filename  : will output Cytoscape JSON of the entity relationships (project, samples, assays, TBC?????)

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
my $dry_run;
my $json_file;
my $json = JSON->new->pretty;
my $samples_file;
my $limit;
my $delete_project;
my $graph_file;

GetOptions("dry-run|dryrun"=>\$dry_run,
	   "json=s"=>\$json_file,
	   "sample-info|samples=s"=>\$samples_file,
	   "limit=i"=>\$limit,
	   "delete=s"=>\$delete_project,
	   "graph-file=s"=>\$graph_file,
	  );

$dry_run = 1 if ($limit);

my ($isatab_dir) = @ARGV;

$samples_file = "$isatab_dir/sample-info.txt" unless ($samples_file);

# should speed things up
$schema->storage->_use_join_optimizer(0);

$schema->txn_do_deferred
  ( sub {

      my $num_projects_before = $projects->count;

      if ($delete_project) {
	my $rip = $projects->find_by_stable_id($delete_project);
	if ($rip) {
	  $rip->delete;
	} else {
	  warn "can't find project $delete_project... continuing but will roll back at end\n";
	  $schema->defer_exception("couldn't find project $delete_project to delete");
	}
      }

      my $project = $projects->create_from_isatab({ directory => $isatab_dir,
						    sample_limit => $limit, });

      if ($json_file) {
	if (open(my $jfile, ">$json_file")) {
	  print $jfile $json->encode($project->as_data_structure);
	  close($jfile);
	} else {
	  $schema->defer_exception("can't write JSON to $json_file");
	}
      }

      if ($samples_file) {
	if (open(my $sfile, ">$samples_file")) {
	  printf $sfile "#%s Project %s (%s) loaded into database %s (which contained %d projects) by %s on %s\n",
	    $dry_run ? ' DRY-RUN' : '',
	    $project->external_id,
            $project->stable_id,
	      $ENV{CHADO_DB_NAME}, $num_projects_before, $ENV{USER}, scalar(localtime);

	  print $sfile "#Sample Name\tVB PopBio Stable ID\tVCF file(s)\tSpecies\tComments...\n";
	  foreach my $stock ($project->stocks) {
	    my $species = $stock->best_species();
	    print $sfile join("\t",
			    $stock->external_id,
			    $stock->stable_id,
			    join(",", grep defined, map { $_->vcf_file } $stock->genotype_assays),
			    (defined $species ? $species->name : "EMPTY -"),
			    map { my $c = $_->value; # change "[topic] comment"
				  $c =~ s/^\[//;     # to "topic<tab>comment"
				  $c =~ s/\] /\t/;
				  $c } $stock->multiprops($schema->types->comment))."\n";
	    if (!defined $species) {
	      $schema->defer_exception("Missing species ID assay(s) or project-wide fallback species for sample '".$stock->external_id."'");
	    }
	  }
	  close($sfile);
	} else {
	  $schema->defer_exception("can't write sample info to $samples_file");
	}
      }

      if ($graph_file) {
	if (open(my $gfile, ">$graph_file")) {
	  print $gfile $json->encode($project->as_cytoscape_graph());
	  close($gfile);
	} else {
	  $schema->defer_exception("can't write graph JSON to $graph_file");
	}
      }

      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );

