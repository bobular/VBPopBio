#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: CHADO_DB_NAME=my_chado_instance bin/global_term_usage_report.pl > term_usage.tsv
#
# option: --terms-file  terms.tsv           # tab delimited files for loading
#         --rels-file   relationships.tsv   # into GUS via InsertOntologyFromTabDelim.pm
#


use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use JSON;
use Getopt::Long;

my $fill_cvtermpath;
my $tab_delim_file;
my $relationships_file;

GetOptions("prefill_cvtermpath|fill_cvtermpath"=>\$fill_cvtermpath,
           "output|terms_file|terms-file=s"=>\$tab_delim_file,
           "rels_file|rels-file=s"=>\$relationships_file,
          );

$fill_cvtermpath = 1 if ($relationships_file);
die "must have --terms and --rels options together\n" if ($relationships_file and not $tab_delim_file);

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $cvterms = $schema->cvterms;

my $cvterms_rs = $cvterms->result_source;

#
# find out which cvterm fields we need to check
#


# ignore cvtermpaths, cvtermprops and cvterm_relationship_*
my @cvterm_relationships = grep !/^(cvterm)/, $cvterms_rs->relationships;

# remember all unique cvterms for cvtermpath prefilling
my %seen_cvterm_ids;


print join("\t", 'Term accession prefix', 'Term accession', 'Term name', 'Number of uses in this context',  'Object type', 'Object column')."\n";

foreach my $relationship (@cvterm_relationships) {
  # find the class it points to
  my $info = $cvterms_rs->relationship_info($relationship);
  my $obj_class = $info->{class};
  next if ($obj_class eq 'Bio::Chado::VBPopBio::Result::Dbxref'); # skip these because all cvterms have Dbxrefs
  next if ($obj_class =~ /::(Mage|Phylogeny|Expression|Library|CellLine|Companalysis|Map|Cv)::/);
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
	$seen_cvterm_ids{$cvterm_id}++;
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


if ($fill_cvtermpath) {
  warn "prefilling cvtermpaths...\n";
  foreach my $cvterm_id (keys %seen_cvterm_ids) {
    my $cvterm = $cvterms->find($cvterm_id);
    $cvterm->recursive_parents();
  }
  # the CC_BY term isn't stored in the database by default (see create_json_for_solr.pl)
  my $default_license = $cvterms->find_by_accession({ term_source_ref => 'VBcv',
                                                      term_accession_number => '0001107' }) || die;
  $default_license->recursive_parents();
}


if ($tab_delim_file) {
  open(TAB, ">$tab_delim_file") || die;

  if ($relationships_file) {
    open(REL, ">$relationships_file") || die;
  }

  foreach my $cvterm_id (keys %seen_cvterm_ids) {
    # print term and optionally recurse to all parents
    print_term($cvterm_id);
  }


  if ($relationships_file) {
    close(REL);
  }

  close(TAB);
}


my %printed_terms; # key is cvterm_id

sub print_term {
  my ($cvterm_id) = @_;

  # don't do anything if this term has already been processed
  return if ($printed_terms{$cvterm_id}++);

  my $cvterm = $cvterms->find($cvterm_id);
  my $dbxref = $cvterm->dbxref;
  # Tab delimited text file with the following header (order matters):
  # id, name, def, synonyms (comma-separated), uri, is_obsolete [true/false]
  my $source_id = $dbxref->accession;
  print TAB join("\t", $source_id, $cvterm->name, $cvterm->definition || '',
                 join(",", $cvterm->cvtermsynonyms->get_column('synonym')->all),
                 "http://purl.obolibrary.org/obo/$source_id", 'false')."\n";

  if ($relationships_file) {
    my @parent_terms = $cvterm->direct_parents()->all;
    foreach my $parent_term (@parent_terms) {
      my $parent_source_id = $parent_term->dbxref->accession;
      print REL join("\t", $source_id, 'subClassOf', $parent_source_id)."\n";
      print_term($parent_term->cvterm_id);
    }
  }

}
