#!/usr/bin/env perl

#
# usage: bin/this_script.pl
#
# (no args)
#
#
#

use strict;
use Carp;
use lib 'lib';  # this is so that I don't have to keep installing BCNA for testing

use Bio::Chado::VBPopBio;
use JSON;

use lib 'bin';
use IRTypes;


my $json = JSON->new->pretty; # useful for debugging

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $projects = $schema->projects;
my $metaprojects = $schema->metaprojects;
my $cvterms = $schema->cvterms;
my $dbxrefs = $schema->dbxrefs;

my $vbcv = $schema->cvs->find({ name => 'VectorBase miscellaneous CV' });
my $vbdb = $schema->dbs->find({ name => 'VBcv' });

$schema->txn_do(
		sub {

		  #
		  # 1. Add all the VBcv terms for KDT60 etc (see IRTypes.pm in this directory)
		  #    with accessions like this VBcv:9000084
		  #    (so that these can be loaded correctly from the phenote file)
		  #

		  while (my ($name, $acc) = each %IRTypes::name2acc) {
		    my ($db_name, $db_acc) = split /:/, $acc;
		    croak unless ($db_name eq 'VBcv' && length($db_acc));
		    my $new_cvterm =
		      $dbxrefs->find_or_create( { accession => $db_acc,
						  db => $vbdb },
						{ join => 'db' })->
						  find_or_create_related('cvterm',
									 { name => $name,
									   definition => 'Temporary IR assay result type',
									   cv => $vbcv
									 });
		  }

		  # sanity check
		  # my $kdt60 = $cvterms->find( { name => 'KDT60', cv => $vbcv } );
		  # warn "kdt60 has name ".$kdt60->name." and db ".$kdt60->dbxref->db->name."\n";


		  #
		  # 2. load the ISA-Tab, directory by directory
		  #
		  # make sure you remove any incomplete studies: e.g. 25, 58, 61, 98, 52, 55
		  #

		  unlink 'temp-ir.json';
		  foreach my $irbase_study_dir (glob('../../data/IRbaseToISAtab-20110606b/study[6789]*')) {

		    warn "loading $irbase_study_dir...\n";
		    my $irbase = $projects->create_from_isatab({ directory => $irbase_study_dir });

		    my $project_json = $json->encode($irbase->as_data_structure);

		    # warn("Project '", $irbase->name, "' was created temporarily as:\n$project_json");

		    if (open(TEMP, ">>temp-ir.json")) { print TEMP $project_json."\n";  close(TEMP); }
		  }

		  $schema->txn_rollback;
    });
