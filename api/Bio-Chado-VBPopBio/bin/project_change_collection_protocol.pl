#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: bin/project_change_collection_protocol.pl --project VBP0000nnn IRO:nnnnnnn
# OR...: bin/project_change_collection_protocol.pl --project VBP0000nnn --old VSMO:0000756 --new IRO:0000031
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
my $old_accession;
my $new_accession;
my $progress = 1;
my $limit;

GetOptions("dry-run|dryrun"=>\$dry_run,
	   "projects=s"=>\$project_ids,
           "old=s"=>\$old_accession,
           "new=s"=>\$new_accession,
           "progress!"=>\$progress,  # --noprogress to disable progress meter
           "limit=i"=>\$limit, # just process N collections per project, implies dry-run
	  );

unless ($old_accession && $new_accession) {
  ($new_accession) = @ARGV;
}

die "incorrect args, see help text at top of script\n" unless ($new_accession);

$dry_run = 1 if ($limit);

$| = 1;

$schema->txn_do_deferred
  ( sub {

      my $new_protocol_term;
      if ($new_accession =~ /^(\w+):(\d+)$/) {
	$new_protocol_term = $cvterms->find_by_accession({ term_source_ref => $1, term_accession_number => $2});
      }
      die "couldn't find $new_accession\n" unless ($new_protocol_term);

      my %previous_protocols;
      foreach my $project_id (split /\W+/, $project_ids) {
	my $project = $schema->projects->find_by_stable_id($project_id);
	unless ($project) {
	  $schema->defer_exception("project '$project_id' not found");
	  next;
	}
        my $done = 0;
        my $todo = $project->field_collections->count();
	warn "processing $project_id...\n";

	$project->update_modification_date() if ($project);

	foreach my $collection ($project->field_collections) {
	  die "ERROR: this script can't handle collections with more than one protocol without providing the --old <accession> option\n" if (!$old_accession && $collection->nd_protocols->count > 1);

	  foreach my $protocol ($collection->nd_protocols) {
	    # remember which protocols we have changed
            my $old_protocol_type = $protocol->type;

            # if we don't care what the old accession was OR
            # if the old accession was what we specifi
            if (!$old_accession ||
                $old_protocol_type->dbxref->as_string eq $old_accession) {

              my $old_name = $old_protocol_type->name;
              $previous_protocols{$old_name}++;
              $protocol->type_id($new_protocol_term->id);
              $protocol->update;
            }
	  }

          printf "\rdone %4d of %4d collections", ++$done, $todo if ($progress);
          last if ($limit && $done >= $limit);
	}
        print "\n" if ($progress);
      }
      warn "replaced these protocols: ".join(", ", sort keys %previous_protocols)."\n";
      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );

