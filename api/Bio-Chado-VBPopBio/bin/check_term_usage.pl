#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: CHADO_DB_NAME=my_chado_instance bin/check_term_usage.pl MIRO:0012345
#
# or bin/check_term_usage.pl -name female
# or                         -accession MIRO:0012345
#
#

use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use JSON;
use Getopt::Long;

my $accession;
my $name;

GetOptions("name=s"=>\$name,
	   "accession=s"=>\$accession);


($accession) = @ARGV if (@ARGV and not $accession);

die "must provide -name or -accession parameter for ontology term or accession\n" unless ($name or $accession);

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $cvterms = $schema->cvterms;


my @cvterms;

if ($accession) {
  my ($term_source, $term_accession) = split /:/, $accession;
  my $cvterm = $cvterms->find_by_accession({ term_source_ref => $term_source,
					     term_accession_number => $term_accession
					   });
  die "can't find cvterm for $accession\n" unless ($cvterm);
  push @cvterms, $cvterm;
} else {
  push @cvterms, $cvterms->search({name => $name})->all;
}


foreach my $cvterm (@cvterms) {
  printf "cvterm %s %s\n", $cvterm->name, $cvterm->dbxref->as_string;
  foreach my $relationship ($cvterm->result_source->relationships) {
    # ignore cvtermpaths, cvtermprops and cvterm_relationship_*
    next if ($relationship =~ /^cvterm/);
    # some DBIx relationships are not actually available
    my $count = eval { $cvterm->$relationship->count };
    printf "\t%-5d %s\n", $count, $relationship if ($count);
  }
}
