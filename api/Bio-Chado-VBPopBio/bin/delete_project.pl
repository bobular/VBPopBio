#!/usr/bin/env perl
# -*- mode: cperl -*-
#
# deletes a project, but only after dumping it to ISA-Tab files in 'output_dir'
#
#
#
# usage: CHADO_DB_NAME=my_chado_instance bin/delete_project.pl --project VBPnnnnnnn --dry-run --output_dir isatab_dir
#
# options:
#   --dry-run              : rolls back transaction and doesn't insert into db permanently
#   --project              : the project stable ID to dump
#   --output_dir           : where to dump the ISA-Tab (defaults to PROJECTID-ISA-Tab-YYYY-MM-DD-HHMM)
#   --verify               : check that the dumped project can be reloaded losslessly
#                            (implies dry-run - so does not delete - use this for archiving)
#   --max_samples          : skip the whole process (no dump, no deletion) if more than this number of samples
#   --ignore-geo-name      : don't validate the contents of 'Collection site (VBcv:0000831)' column

use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use JSON;
use Getopt::Long;
use utf8::all;
use POSIX 'strftime';
use Test::Deep::NoTest qw/cmp_details deep_diag ignore any set/;
use Data::Walk;
use Data::Dumper;

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $projects = $schema->projects;
my $dry_run;
my $json_file;
my $json = JSON->new->pretty;
my $project_id;
my ($verify, $ignore_geo_name);
my $output_dir;
my $max_samples;


GetOptions("dry-run|dryrun"=>\$dry_run,
	   "json=s"=>\$json_file,
	   "project=s"=>\$project_id,
	   "output_dir=s"=>\$output_dir,
	   "verify"=>\$verify,
	   "ignore-geo-name"=>\$ignore_geo_name,
	   "max_samples=i"=>\$max_samples,
	  );

$dry_run = 1 if ($verify);

my ($isatab_dir) = @ARGV;

die "must give --project VBPnnnnnnn arg\n" unless ($project_id);

$output_dir //= sprintf "%s-ISA-Tab-%s", $project_id, strftime '%Y-%m-%d-%H%M', localtime;

# should speed things up
$schema->storage->_use_join_optimizer(0);

$schema->txn_do_deferred
  ( sub {

      my $project = $projects->find_by_stable_id($project_id);
      die "can't find $project_id in database\n" unless ($project);

      my $num_samples = $project->stocks->count;
      if (defined $max_samples && $num_samples > $max_samples) {
	$schema->defer_exception("skipping this project as it has $num_samples samples (more than max_samples option)");
      } else {
	my $project_data = $project->as_data_structure;
	$project->write_to_isatab({ directory=>$output_dir });
	$project->delete;
	if ($verify) {
	  my $reloaded = $projects->create_from_isatab({ directory=>$output_dir });
	  my $reloaded_data = $reloaded->as_data_structure;
	  $reloaded_data->{last_modified_date} = ignore(); # because this will always be different!

print Dumper($project_data->{"stocks"}[1]{"phenotype_assays"}[2]{"props"});
print Dumper($reloaded_data->{"stocks"}[1]{"phenotype_assays"}[2]{"props"});


	  my ($result, $diagnostics) = cmp_details($project_data, preprocess_data($reloaded_data));
	  unless ($result) {
	    $schema->defer_exception("ERROR! Project reloaded from ISA-Tab has differences:\n".deep_diag($diagnostics));
	  }
	}
      }

      $schema->defer_exception("--dry-run or --verify option used - rolling back") if ($dry_run);
    } );


#
# takes a nested data structure and descends into it looking for:
#
# 1. empty strings or undefs and making Test::Deep allow either
#
# 2. props arrays and replacing them with set comparisons (ignore order)
#
# edits data IN PLACE - returns the reference passed to it
#
sub preprocess_data {
  my ($data) = @_;
  $data->{vis_configs} = ignore();

  walk sub {
    my $node = shift;
    if (ref($node) eq 'HASH') {
      foreach my $key (keys %{$node}) {
	if (!defined $node->{$key} || $node->{$key} eq '') {
	  $node->{$key} = any(undef, '');
	} elsif ($key eq 'props') {
	  $node->{$key} = set(@{$node->{$key}});
	} elsif ($key eq 'geolocation' && $ignore_geo_name) {
	  $node->{geolocation}{name} = ignore(); # because we dump the correct term names, but load the user-provided ones
	}
      }
    }
  }, $data;

  return $data;
}
