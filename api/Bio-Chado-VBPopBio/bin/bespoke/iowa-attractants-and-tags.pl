#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: bin/bespoke/iowa-attractants.pl
#
# options:
#   --dry-run              : rolls back transaction and doesn't insert into db permanently
#

use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use Getopt::Long;
use utf8::all;
use feature 'switch';

use aliased 'Bio::Chado::VBPopBio::Util::Multiprop';

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $samples = $schema->stocks;
my $cvterms = $schema->cvterms;
my $projects = $schema->projects;
my $dry_run;

GetOptions("dry-run|dryrun"=>\$dry_run,
	  );



$schema->txn_do_deferred
  ( sub {

      my $attractant_heading = $schema->types->attractant;

      my $light_term = $cvterms->find_by_accession({ term_source_ref => 'IRO', term_accession_number => '0000139'});
      my $CO2_term = $cvterms->find_by_accession({ term_source_ref => 'IRO', term_accession_number => '0000035'});
      my $infusion_term = $cvterms->find_by_accession({ term_source_ref => 'IRO', term_accession_number => '0000037'});

      my $NJLT_id = $cvterms->find_by_accession({ term_source_ref => 'VSMO', term_accession_number => '0000756' })->id;
      my $CDC_light_trap_id = $cvterms->find_by_accession({ term_source_ref => 'VSMO', term_accession_number => '0000727' })->id;
      my $CDC_gravid_trap_id = $cvterms->find_by_accession({ term_source_ref => 'VSMO', term_accession_number => '0001510' })->id;

      foreach my $project_id ('VBP0000194') {
	warn "processing $project_id...\n";
	my $project = $schema->projects->find_by_stable_id($project_id);
	$project->update_modification_date() if ($project);

	$project->add_tag({ term_source_ref => 'VBcv', term_accession_number => '0001094'}) || die; # Iowa
	$project->add_tag({ term_source_ref => 'VBcv', term_accession_number => '0001100'}) || die; # CC BY-NC

	# (tried to do a field_collections->search({...}, {-join=>...}) but couldn't get it to work
	# because type_id is in several tables
	foreach my $collection ($project->field_collections) {
	  foreach my $protocol ($collection->nd_protocols) {

	    given($protocol->type->id) {
	      when($CDC_light_trap_id) {
		$collection->add_multiprop(Multiprop->new(cvterms=>[$attractant_heading, $light_term]));
		$collection->add_multiprop(Multiprop->new(cvterms=>[$attractant_heading, $CO2_term]));
	      }
	      when($CDC_gravid_trap_id) {
		$collection->add_multiprop(Multiprop->new(cvterms=>[$attractant_heading, $infusion_term]));
	      }
	      when($NJLT_id) {
		$collection->add_multiprop(Multiprop->new(cvterms=>[$attractant_heading, $light_term]));
	      }
	    }
	  }
	}
      }


      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );

