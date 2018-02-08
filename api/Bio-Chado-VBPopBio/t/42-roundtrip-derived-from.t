use Test::More tests => 2;

use strict;
use JSON;
use Bio::Chado::VBPopBio;
my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $projects = $schema->projects;

my $json = JSON->new->pretty;
my $verbose = 0; # print out JSON (or not)

my $isatabdir1 = '../../test-data/VectorBase_PopBio_ISA-Tab_full_example';
my $tempdir1 = "/tmp/temp-roundtrip1-$$";
mkdir $tempdir1;

my $isatabdir2 = '../../test-data/VectorBase_PopBio_ISA-Tab_derived-from_example';
my $tempdir2 = "/tmp/temp-roundtrip2-$$";
mkdir $tempdir2;


$schema->txn_do_deferred(
		sub {

		  # read in a project
		  my $project1 = $projects->create_from_isatab({ directory=>$isatabdir1});
		  my $project1_data = $project1->as_data_structure;

		  my $project2 = $projects->create_from_isatab({ directory=>$isatabdir2});
		  my $project2_data = $project2->as_data_structure;
		  $project2->write_to_isatab({ directory=>$tempdir2 });

		  $project1->write_to_isatab({ directory=>$tempdir1 }); # should throw exceptions

		  $project2->delete;


		  my $project2r = $projects->create_from_isatab({ directory=>$tempdir2 });
		  is_deeply($project2r->as_data_structure, $project2_data, "Project 2: JSON data structures the same after delete and reload");

		  is(scalar @{$schema->{deferred_exceptions}}, 2, "Should be two deferred exceptions at this point due to attempt to dump a 'source' project");


		  # we were just pretending!
		  $schema->defer_exception("This exception is thrown intentionally as part of the unit testing process.");
		}
	       );
