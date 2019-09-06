#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: bin/project_add_attractants.pl --project VBP0000nnn IRO:nnnnnnn IRO:mmmmmmmm ...
#
#        also allows comma-separated project IDs.
#
# adds attractants to EVERY collection assay, no questions asked...
#
# options:
#   --dry-run                        : rolls back transaction and doesn't insert into db permanently
#
#   --replace-free-text "light;CO2"  : only add terms when this single free text annotation is present (and remove it, obvs)
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
my $replace;

GetOptions("dry-run|dryrun"=>\$dry_run,
	   "projects=s"=>\$project_ids,
           "replace-free-text=s"=>\$replace,
	  );


my @term_accs = @ARGV;


$schema->txn_do_deferred
  ( sub {

      my $attractant_heading = $schema->types->attractant;

      my @terms = map { $_ =~ /^(\w+):(\d+)$/ ?
			  $cvterms->find_by_accession({ term_source_ref => $1, term_accession_number => $2}) : () } @term_accs;

      die "couldn't find terms for all given accs: @term_accs\n" unless (@term_accs == @terms);

      foreach my $project_id (split /\W+/, $project_ids) {
	warn "processing $project_id...\n";
	my $project = $schema->projects->find_by_stable_id($project_id);
	unless ($project) {
	  warn "project not found\n";
	  next;
	}

	$project->update_modification_date() if ($project);

	foreach my $collection ($project->field_collections) {

          my $ok_to_replace;
          if ($replace) {
            my @attractants_props = $collection->multiprops($attractant_heading);
            if (@attractants_props == 1 && $attractants_props[0]->value eq $replace) {
              my $rip_prop = $collection->remove_multiprop($attractants_props[0]);
              if ($rip_prop) {
                $ok_to_replace = 1;
              } else {
                $schema->defer_exception("Failed to remove '$replace' property for ".$collection->stable_id."\n");
              }
            }
          }
          next if ($replace && !$ok_to_replace);
	  foreach my $term (@terms) {
	    $collection->add_multiprop(Multiprop->new(cvterms=>[$attractant_heading, $term]));
	  }
	}
      }

      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );

