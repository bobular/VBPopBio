#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: bin/flag-deprecated-assays.pl --assay-type species_identification_assay --protocol-type MIRO:30000037 --project VBP0000005 --message "due to species taxonomy changes"
#
#
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
#   --protocol-type        : MIRO:30000037
#                            only assays with this protocol type processed
#
#   --message              : "due to species taxonomy changes" [REQUIRED]
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
my $assay_type;
my $protocol_type;
my $limit;
my $message = "";

# CMD ARGS
GetOptions( "dry-run|dryrun"=>\$dry_run,
	    "assay-type=s"=>\$assay_type,
	    "protocol-type=s"=>\$protocol_type,
	    "limit=i"=>\$limit,
	    "project=s"=>\$project_id,
	    "message=s"=>\$message,
	  );

die "missing args" unless ($message && $assay_type && $project_id);

#
# some cvterms
#
my $deprecated_term = $schema->types->deprecated;

# TRANSACTION WRAPPER
$schema->txn_do_deferred(

    sub{

      #--------------------------------------------------------
      # get projects assays of the assay_type
      #--------------------------------------------------------

      my $project = $schema->projects->find_by_stable_id($project_id);
      my $assays = $project->experiments->search({ 'nd_experiment.type_id' => $schema->types->$assay_type->id });

      # optionally restrict to assays having at least one protocol of the desired type
      if ($protocol_type) {
	my ($ref, $acc) = split /:/, $protocol_type;
	my $protocol_term = $schema->cvterms->find_by_accession({ term_source_ref => $ref,
								  term_accession_number => $acc} );
	die "bad $protocol_type" unless ($protocol_term);

	$assays = $assays->search({ "nd_protocol.type_id" => $protocol_term->id },
				  { join => { 'nd_experiment_protocols' => 'nd_protocol' } });
      }

      my $num_done = 0;
      while (my $assay = $assays->next) {
	my $assay_stable_id = $assay->stable_id;
	# print "Processing ".$assay->type->name." $assay_stable_id protocol(s) ".(join ";", map { $_->type->name } $assay->nd_protocols->all)."\n";

	$assay->add_multiprop(Multiprop->new(cvterms => [ $deprecated_term ], value => $message));

	last if ($limit && ++$num_done >= $limit);
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
