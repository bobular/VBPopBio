#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: bin/project_add_tags.pl --project VBP0000nnn VBcv:nnnnnnn VBcv:mmmmmmmm ...
#
#        also allows comma-separated project IDs.
#
# adds tag(s) to the project(s) given, no questions asked
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

GetOptions("dry-run|dryrun"=>\$dry_run,
	   "projects=s"=>\$project_ids,
	  );


my @term_accs = @ARGV;


$schema->txn_do_deferred
  ( sub {
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

	my $changed_something;
	foreach my $term (@terms) {
	  my $result = $project->add_tag($term);
	  $changed_something = 1 if ($result);
	}
	$project->update_modification_date() if ($changed_something);
      }

      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );

