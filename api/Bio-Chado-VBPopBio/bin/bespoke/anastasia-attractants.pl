#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: zcat /home/maccallr/vectorbase/popbio/data/all_AMCD_attractant.tsv.gz | bin/bespoke/anastasia-attractants.pl
#
# options:
#   --dry-run              : rolls back transaction and doesn't insert into db permanently

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
my $dry_run;

GetOptions("dry-run|dryrun"=>\$dry_run,
	  );



$schema->txn_do_deferred
  ( sub {

      my $attractant_heading = $schema->types->attractant;
      my %done_collection_id;
      my %term_cache;
      my %seen_projects;
      while (<>) {
	my ($sample_id, $project_id, $name, $attractants, $terms) = split;
	next unless ($sample_id && $terms);
	my $sample = $samples->find_by_stable_id($sample_id) || die;
	foreach my $collection ($sample->field_collections) {
	  next if ($done_collection_id{$collection->id}++);
	  foreach my $term_acc (split /,\s*/, $terms) {
	    my $attractant_term = $term_cache{$term_acc} //=
	      $term_acc =~ /^(\w+):(\d+)/ ?
		$cvterms->find_by_accession({ term_source_ref => $1,
					      term_accession_number => $2 }) : undef;
	    $collection->add_multiprop(Multiprop->new(cvterms=>[$attractant_heading, $attractant_term]));
	    $seen_projects{$project_id}++;
	  }
	}
      }
      # update the timestamp on each project
      foreach my $project_id (keys %seen_projects) {
	my $project = $schema->projects->find_by_stable_id($project_id);
	$project->update_modification_date() if ($project);
      }

      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );

