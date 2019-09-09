#!/usr/bin/env perl
# -*- mode: cperl -*-
#
# This script ...
#
#
#
# options:
#
#  --data-dir xxxxx     path to directory containing delete.txt, rem_ids_rounded.csv, zero_samples.txt
#                       default is '../../../data/iowa-float-remediation'
#  --dry-run            don't actually alter the database
#  --limit N            only process first N lines of each file, implies --dry-run
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
my $limit;
my $data_dir = '../../../data/iowa-float-remediation';

GetOptions("dry-run|dryrun"=>\$dry_run,
           "limit=i"=>\$limit, # just process N rows per file
           "data-dir=s"=>\$data_dir,
	  );


$dry_run = 1 if ($limit);

$| = 1;

my $sample_size_term = $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv',
                                                             term_accession_number => '0000983' }) || die;


#
# read in the files
#

# delete.txt
my @delete_ids;
open(FILE, "$data_dir/delete.txt") || die;
while (<FILE>) {
  my ($id) = split;
  push @delete_ids, $id;
  last if (defined $limit && @delete_ids == $limit);
}
close(FILE);

# rem_ids_rounded.csv
my %new_values;  # id => integer
open(FILE, "$data_dir/rem_ids_rounded.csv") || die;
my $headers = <FILE>;
while (<FILE>) {
  chomp;
  # crude CSV parsing - as there are no surprises in the file
  my ($ignore,$id,$integer) = split /,/, $_;
  $new_values{$id} = $integer;
  last if (defined $limit && keys %new_values == $limit);
}
close(FILE);


# zero_samples.txt
my @zero_sample_ids;
open(FILE, "$data_dir/zero_samples.txt") || die;
while (<FILE>) {
  my ($id) = split;
  push @zero_sample_ids, $id;
  last if (defined $limit && @zero_sample_ids == $limit);
}
close(FILE);




$schema->txn_do_deferred
  ( sub {

      foreach my $id (@delete_ids) {
        my $sample = find_sample($id);
        if ($sample) {
          $sample->delete;
        } else {
          $schema->defer_exception("Couldn't find sample for deletion '$id'");
        }
      }

      while (my ($id, $integer) = each %new_values) {
        my $sample = find_sample($id);
        if ($sample) {
          my ($prop) = $sample->multiprops($sample_size_term);
          my $rip_prop = $sample->delete_multiprop($prop);
          if ($rip_prop) {
            $sample->add_multiprop(Multiprop->new(cvterms => [ $sample_size_term ], value => $integer));
          } else {
            $schema->defer_exception("Couldn't find sample_size property for integer remediation '$id'");
          }
        } else {
          $schema->defer_exception("Couldn't find sample for integer remediation '$id'");
        }
      }

      foreach my $id (@zero_sample_ids) {
        my $sample = find_sample($id);
        if ($sample) {
          my ($prop) = $sample->multiprops($sample_size_term);
          my $rip_prop = $sample->delete_multiprop($prop);
          if ($rip_prop) {
            $sample->add_multiprop(Multiprop->new(cvterms => [ $sample_size_term ], value => 0));
          } else {
            $schema->defer_exception("Couldn't find sample_size property for zero remediation '$id'");
          }
        } else {
          $schema->defer_exception("Couldn't find sample for zero remediation '$id'");
        }
      }

      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );



sub find_sample {
  my ($id) = @_;
  my $search = $schema->stocks->search({ name => $id });
  my $sample = $search->next;
  unless ($sample) {
    $schema->defer_exception("Could not find sample: '$id'");
    return;
  }
  if ($search->next) {
    $schema->defer_exception("More than one sample: '$id'");
    return;
  }
  return $sample;
}
