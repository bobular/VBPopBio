#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: bin/fix_date_precision.pl --trim-to month --project VBP0000nnn
#    or: bin/fix_date_precision.pl --trim-to year  --project VBP0000nnn
#
#
# does actually take multiple comma-separated projects but BE CAREFUL
#
# options:
#   --dry-run              : rolls back transaction and doesn't insert into db permanently
#   --verbose

use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use Getopt::Long;
use utf8::all;
use List::MoreUtils qw/uniq/;

use aliased 'Bio::Chado::VBPopBio::Util::Multiprop';

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $samples = $schema->stocks;
my $dry_run;
my $project_ids;
my $trim_level;
my $verbose;

GetOptions("dry-run|dryrun"=>\$dry_run,
	   "projects=s"=>\$project_ids,
           "trim-to=s"=>\$trim_level,
           "verbose"=>\$verbose,
	  );

$| = 1;

die "bad commandline arguments\n" unless ($project_ids && $trim_level && $trim_level =~ /year|month/i);

my $start_date_type = $schema->types->start_date;
my $end_date_type = $schema->types->end_date;
my $date_type = $schema->types->date;

$schema->txn_do_deferred
  ( sub {
      foreach my $project_id (split /\W+/, $project_ids) {
	my $project = $schema->projects->find_by_stable_id($project_id);
	unless ($project) {
	  $schema->defer_exception("project '$project_id' not found");
	  next;
	}
	foreach my $collection ($project->field_collections) {
          printf "Processing project %s collection %s...\n", $project_id, $collection->stable_id if ($verbose);

          my @dates = $collection->multiprops($date_type);
          my @start_dates = $collection->multiprops($start_date_type);
          my @end_dates = $collection->multiprops($end_date_type);

          my @new_date_strings;
          my @rip_props; # properties to delete before adding the new ones

          # first process single dates (not ranges)
          foreach my $date (@dates) {
            my $newdate;
            if ($trim_level =~ /year/i) {
              ($newdate) = $date->value =~ /(\d{4})/;
            } elsif ($trim_level =~ /month/i) {
              ($newdate) = $date->value =~ /(\d{4}-\d\d)/;
            }
            if ($newdate) {
              push @rip_props, $date;
              push @new_date_strings, $newdate;
            }
          }
          # then process date-ranges and turn into single dates as required
          foreach my $start_date (@start_dates) {
            my $end_date = shift @end_dates;
            my $new_start;
            if ($trim_level =~ /year/i) {
              ($new_start) = $start_date->value =~ /(\d{4})/;
            } elsif ($trim_level =~ /month/i) {
              ($new_start) = $start_date->value =~ /(\d{4}-\d\d)/;
            }

            my $new_end;
            if ($trim_level =~ /year/i) {
              ($new_end) = $end_date->value =~ /(\d{4})/;
            } elsif ($trim_level =~ /month/i) {
              ($new_end) = $end_date->value =~ /(\d{4}-\d\d)/;
            }

            my $new_date_or_range;
            if ($new_start && $new_end) {
              if ($new_start eq $new_end) {
                $new_date_or_range = $new_start;
              } else {
                $new_date_or_range = "$new_start/$new_end";
              }
              push @rip_props, $start_date, $end_date;
              push @new_date_strings, $new_date_or_range;
            }
          }

          # remove any redundancy
          @new_date_strings = uniq(@new_date_strings);

          foreach my $rip_prop (@rip_props) {
            printf "\tremoving %s\n", $rip_prop->as_string if ($verbose);
            my $success = $collection->delete_multiprop($rip_prop);
            $schema->defer_exception(sprintf "Project %s collection %s - couldn't delete date prop %s",
                                     $project_id, $collection->stable_id, $rip_prop->as_string) unless ($success);
          }

          foreach my $new_date_string (@new_date_strings) {
            my ($start_date, $end_date) = split '/', $new_date_string;
            if ($end_date) {
              # it's a range, add two props
              my $new_prop1 = $collection->add_multiprop(Multiprop->new(cvterms=>[$start_date_type], value=>$start_date));
              printf "\tadded %s\n", $new_prop1->as_string if ($verbose);
              $schema->defer_exception(sprintf "Project %s collection %s - couldn't add start date prop %s",
                                     $project_id, $collection->stable_id, $start_date) unless ($new_prop1);

              my $new_prop2 = $collection->add_multiprop(Multiprop->new(cvterms=>[$end_date_type], value=>$end_date));
              printf "\tadded %s\n", $new_prop2->as_string if ($verbose);
              $schema->defer_exception(sprintf "Project %s collection %s - couldn't add end date prop %s",
                                     $project_id, $collection->stable_id, $end_date) unless ($new_prop2);

            } else {
              # single date
              my $new_prop = $collection->add_multiprop(Multiprop->new(cvterms=>[$date_type], value=>$new_date_string));
              printf "\tadded %s\n", $new_prop->as_string if ($verbose);
              $schema->defer_exception(sprintf "Project %s collection %s - couldn't add date prop %s",
                                     $project_id, $collection->stable_id, $new_date_string) unless ($new_prop);
            }
          }
	}
      }
      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );

