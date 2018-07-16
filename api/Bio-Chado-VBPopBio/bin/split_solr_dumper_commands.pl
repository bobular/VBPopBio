#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: CHADO_DB_NAME=my_chado_instance bin/split_solr_dumper_commands.pl --max-phenotypes 500 --num-chunks 25 output_prefix | parallel --jobs 4
#
# checks which projects have IR phenotypes (only checking first 'max-phenotypes'),
# and runs these all as one batch (because they need to
# be run together because of the normalisation for the map marker colours)
#
# then splits the other projects up into num-chunks roughly equal in size
#
# and prints out the commands you can run with gnu parallel
#
# the --records argument is passed through to create_json_for_solr.pl
#
#    --ir-only    # only do the IR data
#


use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use JSON;
use Getopt::Long;

my $jobs = 4;
my $num_chunks = 12;
my $records_per_file = 200000;
my $max_phenotypes_to_check = 500;
my $ir_only;

GetOptions("jobs=i"=>\$jobs,
	   "num-chunks=i"=>\$num_chunks,
	   "records_per_file=i"=>\$records_per_file,
	   "max_phenotypes_to_check=i"=>\$max_phenotypes_to_check,
	   "only_ir|only-ir|ir_only|ir-only"=>\$ir_only,
	  );

my ($prefix) = @ARGV;

die "need to give a prefix" unless $prefix;

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });

# should speed things up
$schema->storage->_use_join_optimizer(0);

my $ir_assay_base_term = $schema->cvterms->find_by_accession({ term_source_ref => 'MIRO',
							       term_accession_number => '20000058' });



my $projects = $schema->projects->ordered_by_id;

my %project2size;
my @IRprojects; # stable
my @nonIRprojects; # ids

my $total_projects = $projects->count;
my $done_projects = 0;
while (my $project = $projects->next) {
  my $stable_id = $project->stable_id;
  warn sprintf "scanning %10s for IR phenotypes (%3d / %3d)\n", $stable_id, $done_projects++, $total_projects;
  my $n_samples = $project->stocks->count;
  my $n_assays = $project->experiments->count;

  $project2size{$stable_id} = $n_samples+$n_assays;

  # now figure out if the project is IR
  my $phenotype_assays = $project->phenotype_assays;
  my $is_IR = 0;
  my $done = 0;
  while (my $phenotype_assay = $phenotype_assays->next) {
    my @protocol_types = map { $_->type } $phenotype_assay->protocols->all;
    if (grep { $_->id == $ir_assay_base_term->id ||
		 $ir_assay_base_term->has_child($_) } @protocol_types) {
      $is_IR = 1;
      last;
    }
    last if ($done++ >= $max_phenotypes_to_check);
  }
  if ($is_IR) {
    push @IRprojects, $stable_id;
  } elsif (!$ir_only) {
    push @nonIRprojects, $stable_id;
  }
}

warn "\ndone scan - writing commands\n";

my @commands;
push @commands, sprintf "bin/create_json_for_solr.pl --projects %s --chunksize %d %s-IRall", join(',',@IRprojects), $records_per_file, $prefix;

# assign projects to chunks in round-robin, biggest first
my @projects = sort { $project2size{$b} <=> $project2size{$a} } @nonIRprojects;

my @chunks;
my $i = 0;
while (@projects) {
  my $project = shift @projects;
  push @{$chunks[$i++]}, $project;
  $i = 0 if ($i==$num_chunks);
}

for (my $i=0; $i<@chunks; $i++) {
  # main
  push @commands, sprintf "bin/create_json_for_solr.pl --projects %s --chunksize %d %s-nonIR%02d", join(',',@{$chunks[$i]}), $records_per_file, $prefix, $i+1;
}

# save the commands to a file for later debugging
open(COMMS, ">$prefix.commands") || die;
print COMMS map { "$_\n" } @commands;
close(COMMS);


# and print to STDOUT for chaining with gnu parallel
print map { "$_\n" } @commands;
