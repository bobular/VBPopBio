#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: CHADO_DB_NAME=my_chado_instance bin/check_term_usage.pl MIRO:0012345
#
# to do: maybe lookup by name as well
#

use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use JSON;
use Getopt::Long;

my ($accession) = @ARGV;

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $cvterms = $schema->cvterms;

my ($term_source, $term_accession) = split /:/, $accession;
my $cvterm = $cvterms->find_by_accession({ term_source_ref => $term_source,
					   term_accession_number => $term_accession
					 });


print "$accession => ".$cvterm->name."\n";
foreach my $relationship ($cvterm->result_source->relationships) {
  # ignore cvtermpaths, cvtermprops and cvterm_relationship_*
  next if ($relationship =~ /^cvterm/);
  # some DBIx relationships are not actually available
  my $count = eval { $cvterm->$relationship->count };
  printf "%-5d %s\n", $count, $relationship if ($count);
}
