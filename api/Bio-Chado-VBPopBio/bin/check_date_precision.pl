#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: bin/check_date_precision.pl --projects VBP0000nnn,VBP0000mmm
#
# or --projects ALL
#
# to do: add --fix-dates option
#
# goes through all the collections of each project and reports
# * number of collections
# * number of collections with dates
# * number of no-year errors
# * number of unique dates
# * number of unique monthdays, M
# * number of unique months, m
# * number of unique days, d
# * comma-separated list of monthdays, most common first
# * comma-separated list of months, most common first
# * comma-separated-list of days, most common first
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
my $dry_run;
my $project_ids;

GetOptions("dry-run|dryrun"=>\$dry_run,
	   "projects=s"=>\$project_ids,
	  );

$| = 1;

my $start_date_type = $schema->types->start_date;
my $end_date_type = $schema->types->end_date;
my $date_type = $schema->types->date;

$schema->txn_do_deferred
  ( sub {
      if (lc($project_ids) eq 'all') {
        $project_ids = join(',', map { $_->stable_id } $schema->projects->all);
      }

      print join ("\t", 
                  "#project_ID",
                  "num_collections",
                  "num_with_dates",
                  "num_without_year",
                  "uniq_dates",
                  "uniq_months",
                  "uniq_days",
                  "uniq_monthdays",
                  "months",
                  "days",
                  "monthdays",
                   )."\n";


      foreach my $project_id (split /\W+/, $project_ids) {
	my $project = $schema->projects->find_by_stable_id($project_id);
	unless ($project) {
	  $schema->defer_exception("project '$project_id' not found");
	  next;
	}
        my $done = 0;
        my $num_collections = $project->field_collections->count();
        my $num_with_dates = 0;
        my $num_no_years = 0;
        my %seen_dates;
        my %seen_monthdays;
        my %seen_months;
        my %seen_days;
	foreach my $collection ($project->field_collections) {
          my @dates = map { $_->value } $collection->multiprops($date_type);
          my @start_dates = map { $_->value } $collection->multiprops($start_date_type);
          my @end_dates = map { $_->value } $collection->multiprops($end_date_type);
          if (@dates || @start_dates) {
            $num_with_dates++;

            # join the start/end dates with a slash
            foreach my $date (@dates, map { join('/', $_, shift @end_dates) } @start_dates) {
              if ($date =~ /^(\d{4})/) {
                # it's a good date, starting with a 4 digit year
                $seen_dates{$date}++;
                if (my @months = $date =~ /(?:\d{4})-(\d\d)/g) {
                  my $month = join('/', @months);
                  $seen_months{$month}++;
                  if (my @days = $date =~ /(?:\d{4})-(?:\d\d)-(\d\d)/g) {
                    my $day = join('/', @days);
                    $seen_days{$day}++;
                    if (my @monthdays = $date =~ /(?:\d{4})-(\d\d-\d\d)/g) {
                      my $monthday = join('/', @monthdays);
                      $seen_monthdays{$monthday}++;
                    }
                  }
                }
              } else {
                $num_no_years++;
              }

            }

          }
	}

        print join ("\t", 
                    $project_id,
                    $num_collections,
                    $num_with_dates,
                    $num_no_years,
                    scalar keys %seen_dates,
                    scalar keys %seen_months,
                    scalar keys %seen_days,
                    scalar keys %seen_monthdays,
                    join(',', sort {$seen_months{$b}<=>$seen_months{$a} || $a cmp $b } keys %seen_months),
                    join(',', sort {$seen_days{$b}<=>$seen_days{$a} || $a cmp $b } keys %seen_days),
                    join(',', sort {$seen_monthdays{$b}<=>$seen_monthdays{$a} || $a cmp $b } keys %seen_monthdays),
                   )."\n";
      }
      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );

