#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: bin/remove_zero_virus_assays.pl
#
# options:
#   --dry-run              : rolls back transaction and doesn't insert into db permanently
#
# Some virus assay projects were loaded via SAF with a faulty Wizard converter.
# Assays for zero samples were added.  This script removes them.  It's a one-time
# script because it queries Solr directly.
#
# The script finds 823 assay_ids from a Solr query with these fq's:
#
# bundle:pop_sample_phenotype
# phenotype_type_s:"infection status"
# tags_ss:("Rhode Island Department of Environmental Management" OR "Northwest Mosquito and Vector Control District")
# sample_size_i:0
#
# http://vb-dev.bio.ic.ac.uk:7997/solr/vb_popbio/select?fl=assay_id_s&fq=bundle:pop_sample_phenotype&fq=phenotype_type_s:%22infection%20status%22&fq=sample_size_i:0&fq=tags_ss:(%22Rhode%20Island%20Department%20of%20Environmental%20Management%22%20OR%20%22Northwest%20Mosquito%20and%20Vector%20Control%20District%22)&indent=on&q=*:*&rows=10000&wt=json
#

use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use Getopt::Long;
use utf8::all;
use LWP::Simple::REST qw/json GET/;

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $dry_run;

GetOptions("dry-run|dryrun"=>\$dry_run,
	  );

$| = 1;


$schema->txn_do_deferred
  ( sub {

      # see comments at top for explanation
      my $response = json GET 'http://vb-dev.bio.ic.ac.uk:7997/solr/vb_popbio/select?fl=assay_id_s&fq=bundle:pop_sample_phenotype&fq=phenotype_type_s:%22infection%20status%22&fq=sample_size_i:0&fq=tags_ss:(%22Rhode%20Island%20Department%20of%20Environmental%20Management%22%20OR%20%22Northwest%20Mosquito%20and%20Vector%20Control%20District%22)&indent=on&q=*:*&rows=10000&wt=json';

      my $n = scalar @{$response->{response}{docs}};
      my $count = 0;
      foreach my $assay_id (map { $_->{assay_id_s} } @{$response->{response}{docs}}) {
        printf "\r\tdeleting %3d of $n", ++$count;
        my $assay = $schema->assays->find_by_stable_id($assay_id);
        if (defined $assay) {
          $assay->delete;
        } else {
          $schema->defer_exception("couldn't find assay $assay_id");
        }
      }
      print "\ndone\n";

      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );

