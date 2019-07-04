#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: CHADO_DB_NAME=my_chado_instance bin/global_term_usage_report.pl > term_usage.tsv
#
#

use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use JSON;
use Getopt::Long;

my $fill_cvtermpath;
GetOptions("prefill_cvtermpath|fill_cvtermpath"=>\$fill_cvtermpath);

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $cvterms = $schema->cvterms;

my $cvterms_rs = $cvterms->result_source;


my $tags_root_term = $cvterms->find_by_accession({ term_source_ref => 'VBcv',
                                                   term_accession_number => '0001076' }) || die;

my $projectprops_terms = $schema -> projects ->
                         search_related('projectprops', { rank => { '>=' => 0 } }) ->
                         search_related('type', { }, { distinct => 1 });

print join("\t", "Tag term accession", "Number of projects tagged", "Tag name")."\n";
foreach my $term ($projectprops_terms->all) {
  if ($tags_root_term->has_child($term)) {
    my $dbxref = $term->dbxref;
    my $projects = $schema->projects->search_by_tag({ term_source_ref => $dbxref->db->name,
                                                      term_accession_number => $dbxref->accession });
    print join("\t", $term->dbxref->as_string, $projects->count, $term->name)."\n";

  }
}
