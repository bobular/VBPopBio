#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: bin/project_change_species.pl --project VBP0000nnn --old VBsp:0012345 --new VBsp:0023456
#
#        also allows comma-separated project IDs.
#
# recommend --dry-run
#
# options:
#   --dry-run              : rolls back transaction and doesn't insert into db permanently
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
my $dry_run;
my $project_ids;
my $old_accession;
my $new_accession;

GetOptions("dry-run|dryrun"=>\$dry_run,
	   "projects=s"=>\$project_ids,
           "old=s"=>\$old_accession,
           "new=s"=>\$new_accession,
	  );

unless ($old_accession && $new_accession) {
  die "incorrect args, requires --old VBsp:xxxxxxx --new VBsp:yyyyyyy\n";
}


$| = 1;

$schema->txn_do_deferred
  ( sub {
      my $old_species_term;
      if ($old_accession =~ /^(\w+):(\d+)$/) {
	$old_species_term = $cvterms->find_by_accession({ term_source_ref => $1, term_accession_number => $2});
      }
      die "couldn't find $old_accession\n" unless ($old_species_term);
      my $old_term_id = $old_species_term->id;

      my $new_species_term;
      if ($new_accession =~ /^(\w+):(\d+)$/) {
	$new_species_term = $cvterms->find_by_accession({ term_source_ref => $1, term_accession_number => $2});
      }
      die "couldn't find $new_accession\n" unless ($new_species_term);

      warn sprintf "going to change '%s' to '%s' for all project(s)... kill now if not correct!\n", $old_species_term->name, $new_species_term->name;
      sleep 5;

      my %previous_protocols;
      foreach my $project_id (split /\W+/, $project_ids) {
	my $project = $schema->projects->find_by_stable_id($project_id);
	unless ($project) {
	  $schema->defer_exception("project '$project_id' not found");
	  next;
	}
	warn "processing $project_id...\n";

        my $sp_type_id = $schema->types->species_identification_assay->id;

        my $props =
          $project ->
            experiments ->
              search({ 'nd_experiment.type_id'=>$sp_type_id }) ->
                search_related('nd_experimentprops', { 'nd_experimentprops.type_id' => $old_term_id });

        my $num_changed = $props->count;
        warn sprintf "updating %d species assignments...\n", $props->count;

        if ($num_changed) {
          $props->update( { type_id => $new_species_term->id } );
          $project->update_modification_date();
        }

      }

      warn "replaced these protocols: ".join(", ", sort keys %previous_protocols)."\n";
      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );

