#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: bin/project_change_sample_characteristic.pl [ --dry-run ] --projects VBP0000nnn,VBP0000mmm --old "VBcv:0000983 0.00" --new "VBcv:0000983 0"
#
#
#        also allows comma-separated project IDs.
#
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
my $old_characteristic;
my $new_characteristic;

GetOptions("dry-run|dryrun"=>\$dry_run,
	   "projects=s"=>\$project_ids,
	   "old=s"=>\$old_characteristic,
	   "new=s"=>\$new_characteristic,
	  );


die "need to give --project, --old and --new params\n" unless (defined $project_ids &&
							       defined $new_characteristic &&
							       defined $old_characteristic);


# disable buffering of standard output so the progress update is "live"
$| = 1;

# run everything in a transaction
$schema->txn_do_deferred
  ( sub {

      foreach my $project_id (split /\W+/, $project_ids) {
        print "processing $project_id...\n";
	my $project = $schema->projects->find_by_stable_id($project_id);
	unless ($project) {
	  warn "project not found\n";
	  next;
	}

	my $count_changed = 0;

	my $num_samples = $project->stocks->count;

	my $num_done = 0;
	foreach my $sample ($project->stocks) {
	  my $old_multiprop = process_characteristic($old_characteristic) || die "problem with '$old_characteristic'\n";
	  # see if there is a multiprop matching the --new param, by deleting it
	  if ($sample->delete_multiprop($old_multiprop)) {

	    # process the command line "multiprops"
	    my $new_multiprop = process_characteristic($new_characteristic) || die "problem with '$new_characteristic'\n";

	    # add the new one
	    $sample->add_multiprop($new_multiprop);
	    $count_changed++;
	  }

	  $num_done++;
	  printf "\rprocessed %5d / %5d ...", $num_done, $num_samples;
	}
	print "Finished $project_id, changed $count_changed samples\n";

	$project->update_modification_date() if ($count_changed > 0);

      }
      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );


#
# input: "TGMA:0001234 VBcv:0001234 red"
# (eye, colour, red)
#
# output should be a multiprop built from: $eye_term, $colour_term, "red"
#

sub process_characteristic {
  my ($input) = @_;

  my @components = split " ", $input;
  my @cvterms = ();

  while (@components && $components[0] =~ /^(\w+):(\d+)$/) {
    my $term_source_ref = $1;
    my $term_accession_number = $2;
    my $onto_acc = shift @components;
    my $cvterm = $cvterms->find_by_accession({ term_source_ref => $term_source_ref,
					       term_accession_number => $term_accession_number });
    unless ($cvterm) {
      warn "couldn't find ontology term '$onto_acc'\n";
      return undef;
    }

    push @cvterms, $cvterm;
  }

  # there should be one or zero items left in @components
  if (@components > 1) {
    warn "too many non-ontology term components to multiprop '$input'\n";
    return undef;
  }

  my $value; # undefined by default
  if (@components == 1) {
    $value = shift @components;
  }

  return Multiprop->new(cvterms=>\@cvterms, value=>$value);
}
