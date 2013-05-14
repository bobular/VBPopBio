use Test::More tests => 25;

use strict;
use JSON;
use Bio::Chado::VBPopBio;
my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });


my $projects = $schema->projects;
my $assays = $schema->assays;
my $stocks = $schema->stocks;
# isa_ok($projects, 'Bio::Chado::VBPopBio::ResultSet::Project', "resultset correct class");

my $json = JSON->new->pretty;

$schema->txn_do_deferred(
		sub {
		  my $project1 = $projects->create_from_isatab({ directory=>'../../test-data/VectorBase_PopBio_ISA-Tab_full_example/' });
		  my $project1_data_orig = $project1->as_data_structure;
		  my $project2 = $projects->create_from_isatab({ directory=>'../../test-data/Test-ISA-Tab-pre-existing-VBA-ids/' });
		  my $project2_data_orig = $project2->as_data_structure;

		  # for some reason the last stock has the first (VBA0000001) field collection assay
		  my ($stock1) = sort { $b->external_id cmp $a->external_id } $project1->stocks->all; # reverse sort by "Sample Name" and take first
		  my $stock1_id = $stock1->stable_id;
		  my $stock2 = $project2->stocks->first;

		  my $fc1 = $stock1->field_collections->first;
		  my $fc2 = $stock2->field_collections->first;

		  is($project1->stocks->count, 2, "2 stocks");
 		  is($project2->stocks->count, 2, "also 2 stocks");
		  is($project1->contacts->count, 4, "p1 4 contacts");
		  is($project2->contacts->count, 4, "p2 4 contacts");

		  # the two stocks should have different stable ids
		  isnt($stock1->stable_id, $stock2->stable_id, "different stable ids");
		  # the two stocks should have the same field collection
		  $fc2 = $stock2->field_collections->first;
		  is($fc1->stable_id, $fc2->stable_id, "same field collection stable IDs");
		  is_deeply($fc1, $fc2, "same field collection deeply");

		  is($project1->field_collections->count, 2, "project1 has two field collections");
		  is($project2->field_collections->count, 1, "project2 only one field collection");

		  is($stock2->projects->count, 1, "second stock in just one project");
		  is($fc1->projects->count, 2, "field collection1 is in two projects");
		  is($fc2->projects->count, 2, "field collection2 is in two projects");

		  is($schema->contacts->count, 4, "four contacts in db total");

		  ### NOW DELETE THE FIRST PROJECT
		  $project1->delete;

		  is($schema->contacts->count, 4, "four contacts in db total after p1 delete");

		  is($project2->contacts->count, 4, "p2 before reload still 4 contacts");

		  is($stocks->find_by_stable_id($stock1_id), undef, "stock1 should not be there");

		  # let's refresh project2 stock2 and fc2
		  $project2 = $projects->find_by_stable_id('VBP0000002');
		  $stock2 = $project2->stocks->first;
		  $fc2 = $stock2->field_collections->first;

		  is($project2->contacts->count, 4, "p2 reloaded still 4 contacts");

		  is($fc2->projects->count, 1, "field collection2 is now in one project");

		  ### NOW RELOAD PROJECT1
		  $project1 = $projects->create_from_isatab({ directory=>'../../test-data/VectorBase_PopBio_ISA-Tab_full_example/' });
		  # refresh stocks/fc
		  ($stock1) = sort { $b->external_id cmp $a->external_id } $project1->stocks->all;
		  $fc1 = $stock1->field_collections->first;

		  # refresh fc2 because it was reloaded when project1 was reloaded
		  $project2 = $projects->find_by_stable_id('VBP0000002');
		  $stock2 = $project2->stocks->first;
		  $fc2 = $stock2->field_collections->first;

		  is($fc1->stable_id, $fc2->stable_id, "still same field collection");
		  is_deeply($fc1, $fc2, "same field collection deeply again");

		  is($fc2->projects->count, 2, "field collection2 is now in two projects again");

		  my $project1_data_final = $project1->as_data_structure;
		  my $project2_data_final = $project2->as_data_structure;
		  is(scalar(@{$project1_data_orig->{stocks}}),
		     scalar(@{$project1_data_final->{stocks}}), "project1 data same #stocks before/after");

		  is_deeply($project1_data_orig, $project1_data_final, "proj1 deeply before/after");
		  is_deeply($project2_data_orig, $project2_data_final, "proj2 deeply before/after");

		  # diag($json->encode($project1_data_final->{stocks}[1]));

		  is(scalar(@{$schema->{deferred_exceptions}}), 0, "no deferred exceptions");

		  # we were just pretending!
		  $schema->defer_exception("This is the only exception we should see.");
		}
	       );

