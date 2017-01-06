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

# GetOptions();


my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $cvterms = $schema->cvterms;

my $cvterms_rs = $cvterms->result_source;

#
# find out which cvterm fields we need to check
#


# ignore cvtermpaths, cvtermprops and cvterm_relationship_*
my @cvterm_relationships = grep !/^(cvterm)/, $cvterms_rs->relationships;

print join("\t", 'Term accession prefix', 'Term accession', 'Term name', 'Number of uses in this context',  'Object type', 'Object column')."\n";

foreach my $relationship (@cvterm_relationships) {
  # find the class it points to
  my $info = $cvterms_rs->relationship_info($relationship);
  my $obj_class = $info->{class};
  next if ($obj_class eq 'Bio::Chado::VBPopBio::Result::Dbxref'); # skip these because all cvterms have Dbxrefs
  next if ($obj_class =~ /::(Mage|Phylogeny|Expression|Library|CellLine|Companalysis|Map)::/);
  my $count_objects = $schema->resultset($obj_class)->count;

  # warn ">>$relationship -> $obj_class\n";

  # if there are actually instances of this class
  if ($count_objects) {
    my ($object_column) = keys %{$info->{cond}};
    $object_column =~ s/^foreign\.//;

    my $search = $schema->resultset($obj_class)->search( {},
							 {
							  columns => [ $object_column ],
							  distinct => 1,
							 }
						       );
    my $unique_count = $search->count;
    # warn "$relationship -> $obj_class ($count_objects) -> $object_column ($unique_count)\n";

    # not sure how to join that previous search to return cvterm objects so we'll do it
    # with another step - as there will never be very many
    foreach my $cvterm_id ($search->get_column($object_column)->all) {
      if (defined $cvterm_id) {
	my $cvterm = $cvterms->find($cvterm_id);
	my $dbxref = $cvterm->dbxref;
	my $accession = $dbxref->as_string;
	my $prefix = $dbxref->db->name;
	my $count = $cvterm->search_related($relationship)->count;

	print join("\t", $prefix, $accession, $cvterm->name, $count, $obj_class, $object_column)."\n";

      }
    }
  }
}
