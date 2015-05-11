#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: bin/reannotate-scott-test-results.pl --project VBP0000005
#
#
# The reorganised species taxonomy due to adding coluzzii has meant that the
# Scott test which had the two results: Anopheles gambiae (ss) and Anopheles arabiensis
# is now clashing with the Anopheles coluzzii result of the Favia Fanello test.
# (gambiae ss + coluzzii = gambie sl)
#
# So the result of the Scott test should be really arabiensis or "don't know" (i.e. gambiae s.l.)
#
#
# options:
#
#
#   --project              : VBP0000005 [REQUIRED]
#
#   --assay-type           : species_identification_assay|genotype_assay|phenotype_assay|field_collection [REQUIRED]
#                            only this kind of assay processed
#
#   --dry-run              : rolls back transaction and doesn't insert into db permanently
#
#   --limit 2              : only does 2 assays
#
# Author: Bob MacCallum
#

use strict;
use warnings;
use lib 'lib';
use Bio::Chado::VBPopBio;
use Getopt::Long;
use Data::Dumper;
use aliased 'Bio::Chado::VBPopBio::Util::Multiprops';
use aliased 'Bio::Chado::VBPopBio::Util::Multiprop';
use Tie::IxHash;


# CONNECT TO DATABASE
my $dsn    = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });


# DEFAULT ARGS
my $dry_run;
my $project_id;
my $assay_type = 'species_identification_assay';
my $url = 'http://www.mr4.org/Portals/3/Pdfs/Anopheles/4.2.1%20Anopheles%20gambiae%20complex-Scott%20et%20al%20v%201.pdf';
my $limit;

# CMD ARGS
GetOptions( "dry-run|dryrun"=>\$dry_run,
	    "assay-type=s"=>\$assay_type,
	    "url=s"=>\$url,
	    "limit=i"=>\$limit,
	    "project=s"=>\$project_id,
	  );

die "missing args" unless ($project_id);

#
# some cvterms
#

my $old_species = $schema->cvterms->find_by_accession({ term_source_ref => 'VBsp',
							term_accession_number => '0003829' });  # Anopheles gambiae s.s.
my $old_species_id = $old_species->id;

my $new_species = $schema->cvterms->find_by_accession({ term_source_ref => 'VBsp',
							term_accession_number => '0003480' });  # Anopheles gambiae s.l.
my $new_species_id = $new_species->id;



# TRANSACTION WRAPPER
$schema->txn_do_deferred(

    sub{

      #--------------------------------------------------------
      # get projects assays of the assay_type
      #--------------------------------------------------------

      my $project = $schema->projects->find_by_stable_id($project_id);
      my $assays = $project->species_identification_assays;
      my $to_do = $assays->count;

      my $num_done = 0;
      while (my $assay = $assays->next) {

	# see if it has a single protocol with the correct URL
	if ($assay->protocols->count == 1 && $assay->protocols->first->uri eq $url) {
	  my $assay_stable_id = $assay->stable_id;
	  # print "Processing ".$assay->external_id." $assay_stable_id protocol(s) ".(join ";", map { $_->type->name } $assay->nd_protocols->all)."\n";

	  # because there's no nice way to update multiprops, the
	  # simplest approach is to find the prop with type=Anopheles gambiae
	  # and update it
	  foreach my $prop ($assay->nd_experimentprops->search({ type_id => $old_species_id })->all) {
	    $prop->update({ type_id => $new_species_id });
	  }

	  $num_done++;
	  last if ($limit && $num_done >= $limit);
	  warn "done $num_done out of $to_do\n" if ($num_done % 100 == 0);
	}
      }

      $schema->defer_exception("dry-run option - rolling back") if ($dry_run); # Not sure how this works exactly

    }
);

warn "WARNING: --limit option used without --dry-run - $project_id is only partially done!\n" if ($limit && !$dry_run);

#
# ohr = ordered hash reference
#
# return order-maintaining hash reference
# with optional arguments as key-value pairs
#
sub ohr {
  my $ref = { };
  tie %$ref, 'Tie::IxHash', @_;
  return $ref;
}
