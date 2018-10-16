#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: bin/project_change_collection_protocol.pl --project VBP0000nnn IRO:nnnnnnn
#
#        also allows comma-separated project IDs.
#
# expects ONE protocol per collection and changes it to the ONE provided on the commandline
#
# recommend --dry-run so you can review which protocols you are replacing
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


my ($new_protocol_acc) = @ARGV;

$schema->txn_do_deferred
  ( sub {

      my $new_protocol_term;
      if ($new_protocol_acc =~ /^(\w+):(\d+)$/) {
	$new_protocol_term = $cvterms->find_by_accession({ term_source_ref => $1, term_accession_number => $2});
      }
      die "couldn't find $new_protocol_acc\n" unless ($new_protocol_term);

      my %previous_protocols;
      foreach my $project_id (split /\W+/, $project_ids) {
	warn "processing $project_id...\n";
	my $project = $schema->projects->find_by_stable_id($project_id);
	unless ($project) {
	  warn "project not found\n";
	  next;
	}

	$project->update_modification_date() if ($project);

	foreach my $collection ($project->field_collections) {
	  die "ERROR: this script can't handle project with more than one protocol\n" if ($collection->nd_protocols->count > 1);
	  foreach my $protocol ($collection->nd_protocols) {
	    # remember which protocols we have changed
	    my $old_name = $protocol->type->name;
	    $previous_protocols{$old_name}++;
	    $protocol->type_id($new_protocol_term->id);
	    $protocol->update;
	  }
	}
      }
      warn "replaced these protocols: ".join(", ", sort keys %previous_protocols)."\n";
      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );

