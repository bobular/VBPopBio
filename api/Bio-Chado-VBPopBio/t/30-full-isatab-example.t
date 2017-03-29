use Test::More tests => 41;

use strict;
use JSON;
use Bio::Chado::VBPopBio;
my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $projects = $schema->projects;

my $json = JSON->new->pretty;
my $verbose = 0; # print out JSON (or not)

my $start_date_type = $schema->types->start_date;
my $end_date_type = $schema->types->end_date;
my $date_type = $schema->types->date;

$schema->txn_do_deferred(
		sub {
		  my $project = $projects->create_from_isatab({ directory=>'../../test-data/VectorBase_PopBio_ISA-Tab_full_example' });

		  # make some human readable text from the project and related objects:
#		  my $project_json = $json->encode($project->as_data_structure);
#		  diag("Project '", $project->name, "' was created temporarily as:\n$project_json") if ($verbose);

		  # if (open(TEMP, ">temp-project.json")) { print TEMP $project_json."\n";  close(TEMP); }

		  # run some tests
		  is($project->name, 'Example ISA-Tab for VectorBase PopBio', "project name");
		  is($project->submission_date, '2012-01-01', 'submission date');
		  is($project->public_release_date, '2013-01-01', 'public release date');
		  like($project->creation_date, qr/^\d{4}-\d{2}-\d{2}$/, "project has a sane creation date");
		  like($project->last_modified_date, qr/^\d{4}-\d{2}-\d{2}$/, "project has a sane modification date");

		  # some publications tests
		  my $publications = $project->publications;
		  is($publications->count, 2, "should be two publications");
		  my $pub1 = $publications->next;
		  my $pub2 = $publications->next;
		  is($pub2->title, "A website with lots of information", "pub2 title correct");
		  is($pub2->url, "https://www.vectorbase.org", "pub2 has a URL");


		  my $stock = $project->stocks->first;
		  isa_ok($stock, "Bio::Chado::VBPopBio::Result::Stock", "first stock is a stock");

		  # check best species term (loaded from a MIRO accession)
		  # is from VBsp
		  my ($stock_species, @quals) = $stock->best_species($project);
		  is($stock_species->dbxref->db->name, 'VBsp', "species is really in VBsp");

		  is(scalar(@quals), 1, "stock 1 only one qualifier");
		  is($quals[0]->name, 'ambiguous', "stock 1 ambiguously derived");

		  is($stock->field_collections->count, 1, "stock has 1 FC");
		  my $fc = $stock->field_collections->first;
		  isa_ok($fc, "Bio::Chado::VBPopBio::Result::Experiment::FieldCollection", "fc is correct class");
		  my $geo = $fc->geolocation;
		  isa_ok($geo, "Bio::Chado::VBPopBio::Result::Geolocation", "geo is correct class");


		  is($fc->protocols->first->uri, 'http://whqlibdoc.who.int/offset/WHO_OFFSET_13_(part2).pdf', "field collection protocol URI");

		  is($stock->genotype_assays->count, 3, "stock has three genotype_assays");

		  # karyotype assay is loaded first (comes first in investigation sheet)
		  my ($ka, $ga, $sa) = $stock->genotype_assays->all;

#		  isa_ok($ka, "Bio::Chado::VBPopBio::Result::Experiment::GenotypeAssay", "genotype_assay is correct class");


#		  is($ka->protocols->first->description, "Inversion karyotypes were determined via Giemsa staining and visual inspection under light microscopy", "protocol description");


		  my $spa = $stock->species_identification_assays->first;
		  is($spa->description, "This was a really nice assay.", "species id assay description");

		  # my $kap = $ka->protocols;



#		  is($project->stocks->count, 60, "60 stocks");
#		  is($project->field_collections->count, 4, "4 field collections");
#		  is($project->genotype_assays->count, 60, "60 genotype assays");
#		  is($project->phenotype_assays->count, 0, "0 phenotype assays");
#		  is($project->stocks->first->nd_experiments->count, 3, "3 assays for one stock");
#

		  my @samples = $project->stocks->all;
		  my $sample3 = $samples[2]; # Date: 2010-11-12;2010-11-15
		  my $fc3 = $sample3->field_collections->first;
		  is(scalar $fc3->multiprops($start_date_type), 0, "shouldn't have start or end dates");
		  is(scalar $fc3->multiprops($end_date_type), 0, "shouldn't have start or end dates");
		  is(scalar $fc3->multiprops($date_type), 2, "should have two date multiprops");


		  my $sample4 = $samples[3]; # Date: 2010-11/2010-12;2011-09/2011-11
		  my $fc4 = $sample4->field_collections->first;
		  is(scalar $fc4->multiprops($start_date_type), 2, "should have 2 start dates");
		  is(scalar $fc4->multiprops($end_date_type), 2, "should have 2 end dates");
		  is(scalar $fc4->multiprops($date_type), 0, "should have no date multiprops");

		  is($fc4->duration_in_days(), undef, "should be undefined duration as it is in month resolution");

		  my $sample5 = $samples[4]; # Date: 2010-11-12/2010-11-13;2010-11-15
		  my $fc5 = $sample5->field_collections->first;
		  is(scalar $fc5->multiprops($start_date_type), 1, "should have 1 start date");
		  is(scalar $fc5->multiprops($end_date_type), 1, "should have 1 end date");
		  is(scalar $fc5->multiprops($date_type), 1, "should have 1 date multiprop");

		  is($fc5->duration_in_days(), 3, "complex range is three days");

		  my $fc6 = $samples[5]->field_collections->first; # overlapping range 2010-01-15/2010-01-19;2010-01-19/2010-01-21
		  is($fc6->duration_in_days(), 7, "overlapping ranges should be 7 days all told");

		  # warn $json->encode($fc5->as_data_structure);



		  my $project2 = $projects->create_from_isatab({ directory=>'../../test-data/VectorBase_PopBio_ISA-Tab_derived-from_example' });
		  my $project2_json = $json->encode($project2->as_data_structure);

		  # reload project1 to see changes made by project2 (samples now have manipulations)
		  my $project1 = $projects->find_by_stable_id('VBP0000001');
		  my $project1_json = $json->encode($project1->as_data_structure);


		  is($project1->stocks->first->sample_manipulations->count, 1, "project 1 stocks have manipulations");
		  is($project1->stocks->first->sample_manipulations->first->stocks_created->first->stable_id, $project2->stocks->first->stable_id, "project 1's stock creates project 2's stock");
		  is($project2->stocks->first->sample_manipulations->first->stocks_used->first->stable_id, $project1->stocks->first->stable_id, "and the same the other way round");

		  is($project1->stocks->count, 6, "project 1 still only has 6 stocks");

		  diag("Project1 '", $project1->name, "' was created temporarily as:\n$project1_json") if ($verbose);
		  diag("Project2 '", $project2->name, "' was created temporarily as:\n$project2_json") if ($verbose);

		  # second stock in project2 has no species assays but still should have a species
		  # via project1
		  my ($p1s1, $p1s2) = $project1->stocks->all;
		  my ($p2s1, $p2s2) = $project2->stocks->all;
		  is($p2s2->species_identification_assays->count, 0, "project2 stock2 no species assays");
		  my ($p2s2_species, @qualifiers) = $p2s2->best_species($project2);
		  is($p2s2_species && $p2s2_species->name, $p1s2->best_species->name, "project2 stock2 species derived from project1 stock2");

		  my ($p1s2_species, @qual2) = $p1s2->best_species($project1);
		  is($p1s2_species->dbxref->db->name, 'VBsp', "semicolon delimited species result is loaded as VBsp");
		  is($qual2[0]->name, 'unambiguous', "albimanus should be unambiguous even though it's from two results");
		  # warn "p1s2 species is ".$p1s2_species->name."\n";

		  is(scalar(@qualifiers), 2, "should be two qualifiers");
		  is($qualifiers[0]->name, 'derived', "first species qualification is 'derived'");

		  is(scalar(@{$schema->{deferred_exceptions}}), 0, "no deferred exceptions");
		  # we were just pretending!
		  $schema->defer_exception("This is the only exception we should see.");
		}
	       );
