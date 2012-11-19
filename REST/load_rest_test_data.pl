#!/usr/bin/perl -w

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

# for IRbase result types
use lib 'bin';
use IRTypes;
##

my $json = JSON->new->pretty;

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $projects = $schema->projects;
my $metaprojects = $schema->metaprojects;

my $dbxrefs = $schema->dbxrefs;
my $cvterms = $schema->cvterms;

my $vbcv = $schema->cvs->find({ name => 'VectorBase miscellaneous CV' });
my $vbdb = $schema->dbs->find({ name => 'VBcv' });


#
# IRBASE
#


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

		  #
		  # 2. load the ISA-Tab, directory by directory
		  #
		  # make sure you remove any incomplete studies: e.g. 25, 58, 61, 98, 52, 55
		  #

		  foreach my $irbase_study_dir (glob('../../data/IRbaseToISAtab-20110606b/study*')) {
		    warn "loading $irbase_study_dir...\n";
		    my $irbase = $projects->create_from_isatab({ directory => $irbase_study_dir });
		  }
    });

warn "done irbase\n";

#
# NEAFSEY
#

$schema->txn_do(
		sub {
		    my $neafsey = $projects->create_from_isatab({ directory=>'../../data/Besansky-AgSNP-ISA-Tab/' });
    });

warn "done neafsey\n";

#
# UCDAVIS
#

$schema->txn_do(
		sub {
		    my $ucdavis = $projects->create_from_isatab({ directory=>'../../data/ucdavis' });
    });

warn "done ucdavis\n";

#
# meta-UCDAVIS
#

# this is an experimental factor
my $sampling_time = $dbxrefs->find({ accession => '0000689', version => '', 'db.name' => 'EFO' },
				   { join => 'db' })->cvterm;
die "couldn't find 'sampling time' cvterm\n" unless (defined $sampling_time);

$schema->txn_do(
		sub {

		  foreach my $country ('Mali', 'Cameroon', 'Equatorial Guinea', 'Sao Tome and Principe', 'Guinea', 'Tanzania') {
		    my $years_with_data = 0;
		    foreach my $year (2002 .. 2007) {
		      # search for the constituent stocks and project(s)
		      my $stocks = $schema->stocks->search_by_project({ 'project.name' => 'UC Davis/UCLA population dataset' })
			->search_by_nd_experimentprop({ 'type.name' => 'start date',
							'nd_experimentprops.value' => { like => "$year%" } })
			  ->search_by_nd_geolocationprop({ 'type_2.name' => 'collection site country',
							   'nd_geolocationprops.value' => $country });

		      my $n_stocks = $stocks->count;
		      next unless ($n_stocks);

		      my $projects = $schema->projects->search({ name => 'UC Davis/UCLA population dataset' });

		      my $name = "UC Davis/UCLA population data subset $country $year";
		      my $description = $projects->first->description." This is a subset of the data: mosquitoes collected in $country during $year.";

		      warn "Making metaproject $name ($description) from $n_stocks stocks\n";
		      # make the metaproject
		      my $metaproject = $metaprojects->create_with( { name => $name,
								      description => $description,
								      stocks => $stocks->reset,
								      projects => $projects->reset,
								      # no experimental_factors
								    });
		      $years_with_data++;
		    }

		    ######
		    # now make a whole-country project with year as the experimental factor
		    ######
		    if ($years_with_data > 1) {
			my $stocks = $schema->stocks->search_by_project({ 'project.name' => 'UC Davis/UCLA population dataset' })
			    ->search_by_nd_geolocationprop({ 'type.name' => 'collection site country',
							     'nd_geolocationprops.value' => $country });

			my $n_stocks = $stocks->count;
			next unless ($n_stocks);

			my $projects = $schema->projects->search({ name => 'UC Davis/UCLA population dataset' });

			my $name = "UC Davis/UCLA population data subset $country all years";
			my $description = $projects->first->description." This is a subset of the data: mosquitoes collected in $country.";

			warn "Making metaproject $name ($description) from $n_stocks stocks\n";
			# make the metaproject
			my $metaproject = $metaprojects->create_with( { name => $name,
									description => $description,
									stocks => $stocks->reset,
									projects => $projects->reset,
									experimental_factors => [ $sampling_time ],
									object_paths => [ "nd_experiments:type.name='field collection'->nd_geolocationprops:type.name='start date'->value" ], # complete guess
								      });
		    }
		  }
		});


