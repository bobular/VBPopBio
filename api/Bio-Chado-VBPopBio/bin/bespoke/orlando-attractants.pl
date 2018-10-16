#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: bin/bespoke/orlando-attractants.pl
#
# options:
#   --dry-run              : rolls back transaction and doesn't insert into db permanently

use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use Getopt::Long;
use utf8::all;

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
      my $CDC_light_trap_id = $cvterms->find_by_accession({ term_source_ref => 'VSMO', term_accession_number => '0000727' })->id;
      my $date_type = $schema->types->date;

      foreach my $project_id ('VBP0000257'..'VBP0000262') {
	warn "processing $project_id...\n";
	my $project = $schema->projects->find_by_stable_id($project_id);
	$project->update_modification_date() if ($project);

	foreach my $collection ($project->field_collections) {
	  my ($date_prop) = $collection->multiprops($date_type);
	  if ($date_prop) {
	    my $date = $date_prop->value;
	    if ($date lt '2006-05-01') {
	      $collection->add_multiprop(Multiprop->new(cvterms=>[$attractant_heading, $light_term]));
	    } else {
	      # the following is the correct way to add multiple values
	      # for an ISA-Tab "characteristic column", as seen in Multiprops::add_multiprops_from_isatab_characteristics()
	      $collection->add_multiprop(Multiprop->new(cvterms=>[$attractant_heading, $light_term]));
	      $collection->add_multiprop(Multiprop->new(cvterms=>[$attractant_heading, $CO2_term]));
	    }
	  }

	  foreach my $protocol ($collection->nd_protocols) {
	    if ($protocol->name eq 'baited light trap catch') {
	      $protocol->type_id($CDC_light_trap_id);
	      $protocol->update;
	    }
	  }
	}
      }


      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );

