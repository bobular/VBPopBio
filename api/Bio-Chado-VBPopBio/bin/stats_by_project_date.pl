#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: CHADO_DB_NAME=my_chado_instance bin/stats_by_project_date
#
# outputs a tab delimited list of dates and sample, assay, etc numbers
#
# the date is the "first in vectorbase" date
#
# the total number of samples etc on that date are shown
#
# plotting in R:
#
# popbio <- read.table("stats-by-date-VB-2017-06.tsv", header=TRUE)
# plot(popbio$date, popbio$samples, type="l")
# lines(popbio$date, popbio$collections)
#
# but will try the latest excel...
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

# should speed things up
$schema->storage->_use_join_optimizer(0);



my $projects = $schema->projects;

my %date2samplecount;
my %date2collectioncount;
my %date2phenotypecount;
my %date2genotypecount;
my %date2projectcount;
my %date2projectids; # {date} => {project_id} => 1

while (my $project = $projects->next) {
  my $stable_id = $project->stable_id;
  my $date = $project->creation_date;

  my $n_samples = $project->stocks->count;
  my $n_collections = $project->field_collections->count;
  # the following two actually only cound the number of linkers but these are 1:1 with phenotypes and genotypes
  my $n_phenotypes = $project->phenotype_assays->search_related('nd_experiment_phenotypes')->count;
  my $n_genotypes = $project->genotype_assays->search_related('nd_experiment_genotypes')->count;

  $date2projectcount{$date}++;
  $date2samplecount{$date} += $n_samples;
  $date2collectioncount{$date} += $n_collections;
  $date2phenotypecount{$date} += $n_phenotypes;
  $date2genotypecount{$date} += $n_genotypes;
  $date2projectids{$date}{$stable_id} = 1;
}

my ($sum_samples, $sum_collections, $sum_phenotypes, $sum_genotypes, $sum_projects) = (0,0,0,0,0);

print "date\tprojects\tcollections\tsamples\tphenotypes\tgenotypes\tproject_ids\n";

foreach my $date (sort keys %date2samplecount) {
  printf "%s\t%d\t%d\t%d\t%d\t%d\t%s\n",
    $date,
      ($sum_projects += $date2projectcount{$date}),
	($sum_collections += $date2collectioncount{$date}),
	  ($sum_samples += $date2samplecount{$date}),
	    ($sum_phenotypes += $date2phenotypecount{$date}),
	      ($sum_genotypes += $date2genotypecount{$date}),
		join(",", sort keys %{$date2projectids{$date}});
}
