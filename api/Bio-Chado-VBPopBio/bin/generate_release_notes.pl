#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: CHADO_DB_NAME=my_chado_instance bin/generate_release_notes.pl 2016-12-23 > temp.html
#
# the date should be day after the last popbio production work for the previous release
# see https://docs.google.com/spreadsheets/d/1vUCOBwNcsLhNX8DabGLtJ_0VoiZyRbyvD8IAp1KVb98/edit
# for more details
#

use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use JSON;
use Getopt::Long;


my $cutoff_date = shift || die "must give a date on the command line\n";

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });

# should speed things up
$schema->storage->_use_join_optimizer(0);



my $projects = $schema->projects;


my (@new_projects, @updated_projects);

while (my $project = $projects->next) {
  if ($project->last_modified_date gt $cutoff_date) {
    if ($project->creation_date gt $cutoff_date) {
      push @new_projects, $project;
    } else {
      push @updated_projects, $project;
    }
  } else {
    # print "old project\n";
  }
}

my $num_new = @new_projects;
printf "%d project%s have been added:<br/>\n<ul>\n", $num_new, $num_new > 1 ? 's' : '';
foreach my $project (@new_projects) {
  printf "<li>%s</li>\n", project_summary($project);
}
print "</ul>\n";

my $num_updated = @updated_projects;
printf "%d project%s have been updated (usually to fix minor data inconsistencies):<br/>\n<ul>\n", $num_updated, $num_updated > 1 ? 's' : '';
foreach my $project (@updated_projects) {
  printf "<li>%s</li>\n", project_summary($project);
}
print "</ul>\n";



sub project_summary {
  my $project = shift;
  my $n_samples = $project->stocks->count;
  my $n_collections = $project->field_collections->count;
  # the following two actually only cound the number of linkers but these are 1:1 with phenotypes and genotypes
  my $n_phenotypes = $project->phenotype_assays->search_related('nd_experiment_phenotypes')->count;
  my $n_genotypes = $project->genotype_assays->search_related('nd_experiment_genotypes')->count;


  return sprintf qq[<a href="/popbio/project?id=%s">%s</a> (%d samples, %d collections, %d phenotypes, %d genotypes)],
    $project->stable_id, $project->name,
      # $project->contacts->first->description,
      $n_samples, $n_collections, $n_phenotypes, $n_genotypes;
}

