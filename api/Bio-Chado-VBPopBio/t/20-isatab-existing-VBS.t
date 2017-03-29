use Test::More tests => 6;

use strict;
use JSON;
use Bio::Chado::VBPopBio;
my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });


my $projects = $schema->projects;
# isa_ok($projects, 'Bio::Chado::VBPopBio::ResultSet::Project', "resultset correct class");

my $json = JSON->new->pretty;

$schema->txn_do_deferred(
		sub {
		  my $project1 = $projects->create_from_isatab({ directory=>'../../test-data/VectorBase_PopBio_ISA-Tab_full_example/' });
		  my $project1_lone_data = $project1->as_data_structure;
		  my $project2 = $projects->create_from_isatab({ directory=>'../../test-data/Test-ISA-Tab-pre-existing-VBS-ids/' });

		  my $stock1 = $project1->stocks->first;
		  my $stock2 = $project2->stocks->first;

		  my $project1_data_orig = $project1->as_data_structure;

		  # test for project filtering in as_data_structure chain
		  is_deeply($project1_data_orig, $project1_lone_data, "is project 1 as_data same as before project2 was loaded");

		  my $project2_data_orig = $project2->as_data_structure;

#		  warn "project 1 stock uniquename = ".$stock1->uniquename."\n";
#		  warn "project 2 stock uniquename = ".$stock2->uniquename."\n";

		  is($project1->stocks->count, 6, "6 stocks");
		  is($stock1->external_id, $stock2->external_id, "stocks should have same external id");
		  is(scalar(@{$schema->{deferred_exceptions}}), 0, "no deferred exceptions");

		  # delete project1 and reload both
		  $project1->delete;
		  # this one from file
		  $project1 = $projects->create_from_isatab({ directory=>'../../test-data/VectorBase_PopBio_ISA-Tab_full_example/' });
		  # this one from the database
		  $project2 = $projects->find_by_stable_id($project2->stable_id);

		  my $project1_data_after = $project1->as_data_structure;
		  my $project2_data_after = $project2->as_data_structure;
		  is_deeply($project1_data_after, $project1_data_orig, "project1 is still deeply the same");
		  is_deeply($project2_data_after, $project2_data_orig, "project2 is still deeply the same");

#		  diag("P1 BEFORE:\n".$json->encode($project1_data_orig));
#		  diag("P1 AFTER ****************:\n".$json->encode($project1_data_after));

		  # we were just pretending!
		  $schema->defer_exception("This is the only exception we should see.");
		}
	       );

