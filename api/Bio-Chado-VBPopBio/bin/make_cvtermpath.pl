#!/usr/bin/env perl

#
# usage: bin/make_cvtermpath.pl PREFIX | psql -q $CHADO_DB_NAME
#
# e.g. if prefix is GO then make the cvtermpath for all cvterms with dbxrefs with db.name = 'GO'
#
# recursion code taken from GMOD's chado/bin/make_cvtermpath.pl thanks to the author of that!
#
# known limitations: somewhat hacked to only follow is_a or part_of relationships
# but it doesn't store this info in cvtermpath.type_id - what the script actually does
# is IGNORE relationships that are not OBO_REL:is_a or OBO_REL:part_of
#

use strict;
use lib 'lib';  # this is so that Bio::Chado::VBPopBio does not actually have to be installed
use Bio::Chado::VBPopBio;
use Getopt::Long;

my $dbname = $ENV{CHADO_DB_NAME};
my $dbuser = $ENV{USER};
my $dry_run;

GetOptions("dbname=s"=>\$dbname,
	   "dbuser=s"=>\$dbuser,
	   "dry-run|dryrun"=>\$dry_run,
	  );

my ($prefix) = @ARGV;
die "must give prefix, e.g. GO or MIRO, on commandline\n" unless ($prefix);

my $dsn = "dbi:Pg:dbname=$dbname";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $dbuser, undef, { AutoCommit => 1 });

my $db = $schema->dbs->find({name => $prefix});
my $cvterms = $schema->cvterms->search({
					### 'me.name' => 'Aedes aegypti', ### testing only
					'db.name' => $prefix,
					is_obsolete => 0,
				       },
				       { join => { dbxref => 'db' }});

my $n_terms = $cvterms->count;
die "can't find any cvterms with dbxref.db.name = '$prefix'" unless ($n_terms);

my $isa = $schema->types->is_a;
my $partof = $schema->types->part_of;

warn "Going to process $n_terms terms from $prefix\n";

my %done_subject_object;

while (my $cvterm = $cvterms->next) {
  # only process leaf terms
  if ($cvterm->cvterm_relationship_objects->count == 0) {
    warn "processing leaf term: ".$cvterm->name."\n";

    recurse([$cvterm], 1);

  }
}


sub recurse {
  my($subjects,$dist) = @_;

  my $subject = $subjects->[-1];

  my $objects = $subject->cvterm_relationship_subjects->
      search({ type_id => { -in => [ $isa->id, $partof->id ] }})->search_related('object');

  while (my $object = $objects->next) {
    my $tdist = $dist;
    foreach my $s (@$subjects){
      # warn $s->name." distance $tdist to ".$object->name."\n";

      unless ($done_subject_object{$s->id}{$object->id}{$tdist}++) {
	printf "insert into cvtermpath (subject_id,object_id,cv_id,pathdistance) values (%d,%d,%d,%d);\n",
	  $s->id, $object->id, $s->cv->id, $tdist;
	printf "insert into cvtermpath (subject_id,object_id,cv_id,pathdistance) values (%d,%d,%d,%d);\n",
	  $object->id, $s->id, $object->cv->id, -$tdist;
      }

      $tdist--;
    }
    recurse([@$subjects,$object],$dist+1);
  }
}

