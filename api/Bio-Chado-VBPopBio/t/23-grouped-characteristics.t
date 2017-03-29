use Test::More tests => 17;

use strict;
use JSON;
use Bio::Chado::VBPopBio;
my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $projects = $schema->projects;

my $json = JSON->new->pretty;
my $verbose = 0; # print out JSON (or not)

$schema->txn_do_deferred(
		sub {
		  my $project = $projects->create_from_isatab({ directory=>'../../test-data/Grouped-Characteristics' });

		  isnt($project, undef, "project shouldn't be undef");

		  my @samples = $project->stocks->all;
		  my $sample = shift @samples;

		  isnt($sample, undef, "first sample shouldn't be undef");

		  # get the sample multiprop for organism part
		  my $organism_part = $schema->cvterms->find_by_accession( { term_source_ref => 'EFO', term_accession_number => '0000635' });

		  # test an all-cvterm multiprop
		  my ($eye_color) = $sample->multiprops($organism_part);
		  isnt($eye_color, undef, "eye color multiprop shouldn't be undef");

		  my @ec_cvterms = $eye_color->cvterms;
		  is(scalar @ec_cvterms, 4, "first sample eye colour multiprop should have four cvterms");
		  is($eye_color->value, undef, "first sample eye colour has no free text value");

		  # test a sample multiprop with a free text value
		  my $rainbow = pop @samples;
		  my ($rainbow_eye_color) = $sample->multiprops($organism_part);
		  isnt($rainbow_eye_color, undef, "eye color multiprop shouldn't be undef");

		  my @rainbow_ec_cvterms = $rainbow_eye_color->cvterms;
		  is(scalar @rainbow_ec_cvterms, 3, "last sample eye colour multiprop should have three cvterms");
		  is($rainbow_eye_color->value, 'rainbow', "last sample has free text eye colour");


		  # test the species assay for its microscope props
		  my ($spassay) = $sample->species_identification_assays();
		  isnt($spassay, undef, "should be a sp id assay");

		  my @multiprops = $spassay->multiprops;
		  is(scalar @multiprops, 2, "should have two multiprops");
		  # first multiprop should be the microscope one
		  my ($image_acquisition, $species_assay_result) = @multiprops;
		  my @ia_cvterms = $image_acquisition->cvterms;
		  is(scalar @ia_cvterms, 4, "image acquisition multiprop has 4 terms");
		  is($ia_cvterms[0]->dbxref->as_string, 'OBI:0000398', "image acquisition first cvterm is OBI:0000398");
		  is($ia_cvterms[1]->dbxref->as_string, 'OBI:0000940', "image acquisition second cvterm is OBI:0000940");
		SKIP: {
		    skip "Not enough cvterms to test", 2 if (@ia_cvterms<4);
		    is($ia_cvterms[2]->dbxref->as_string, 'PATO:0000011', "image acquisition third cvterm is PATO:0000011");
		    is($ia_cvterms[3]->dbxref->as_string, 'UO:0000036', "image acquisition fourth cvterm is UO:0000036");
		}
		  is($image_acquisition->value, 5, "image acquisition value is 5");


		  is($sample->best_species->name, "Anopheles nuneztovari", "species is Anopheles nuneztovari");

		  $schema->defer_exception("This is the exception which does the roll-back.");
		}
	       );
