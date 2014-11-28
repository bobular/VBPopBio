#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# CAREFUL!!!! use only to replace obsolete terms with new ones and do it CAREFULLY!
#
# usage: CHADO_DB_NAME=my_chado_instance bin/replace_term.pl OLD_ACCESSION NEW_ACCESSION
#
#
#

use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use JSON;
use Getopt::Long;

my $json = JSON->new->pretty;
my $dry_run;
GetOptions("dry-run|dryrun|dry_run"=>\$dry_run);

my ($old_accession, $new_accession) = @ARGV;

die "must provide old and new accessions for ontology term to be replaced\n"
  unless ($old_accession && $new_accession && $old_accession ne $new_accession);

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $cvterms = $schema->cvterms;

my ($old_term_source, $old_term_accession) = split /:/, $old_accession;
my $old_cvterm = $cvterms->find_by_accession({ term_source_ref => $old_term_source,
					       term_accession_number => $old_term_accession
					     });
die "can't find cvterm for $old_accession\n" unless ($old_cvterm);


my ($new_term_source, $new_term_accession) = split /:/, $new_accession;
my $new_cvterm = $cvterms->find_by_accession({ term_source_ref => $new_term_source,
					       term_accession_number => $new_term_accession
					     });
die "can't find cvterm for $new_accession\n" unless ($new_cvterm);
my $new_cvterm_id = $new_cvterm->cvterm_id;

# remember relationships now because the eval { } doesn't work inside the transaction block...
my @relationships;
printf "OLD cvterm %s %s\n", $old_cvterm->name, $old_cvterm->dbxref->as_string;
foreach my $relationship ($old_cvterm->result_source->relationships) {
  # ignore cvtermpaths, cvtermprops and cvterm_relationship_*
  next if ($relationship =~ /^cvterm/);
  # some DBIx relationships are not actually available
  my $count = eval { $old_cvterm->$relationship->count };
  if ($count) {
    printf "\t%-5d %s\n", $count, $relationship if ($count);
    push @relationships, $relationship;
  }
}

printf "NEW cvterm %s %s\n", $new_cvterm->name, $new_cvterm->dbxref->as_string;
foreach my $relationship ($new_cvterm->result_source->relationships) {
  # ignore cvtermpaths, cvtermprops and cvterm_relationship_*
  next if ($relationship =~ /^cvterm/);
  # some DBIx relationships are not actually available
  my $count = eval { $new_cvterm->$relationship->count };
  if ($count) {
    printf "\t%-5d %s\n", $count, $relationship if ($count);
  }
}



#print "Proceed? ";
#my $answer = <STDIN>;
#exit unless ($answer =~ /^y/i);

printf "REPLACING...\n";

$schema->txn_do_deferred
  ( sub {

      foreach my $relationship (@relationships) {

	my $info = $old_cvterm->result_source->relationship_info($relationship);
	# printf "relationship $relationship : %s\n", $json->encode($info);

	my @fkeys = keys %{$info->{cond}};
	if (@fkeys == 1) {
	  my ($foreign_column) = $fkeys[0] =~ /foreign.(\w+)/;
	  if ($foreign_column) {
	    print "updating $relationship column $foreign_column = $new_cvterm_id\n";
	    my $rels = $old_cvterm->$relationship;
	    while (my $rel = $rels->next) {
	      $rel->update({ $foreign_column => $new_cvterm_id });
	    }

	  } else {
	    $schema->defer_exception("unexpected constraint '$fkeys[0]' can't parse");
	  }

	} else {
	  $schema->defer_exception("complex foreign key relationship for $relationship");
	}
      }


      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);

    }
  );

