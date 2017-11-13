use Test::More tests => 1;

use strict;
use JSON;
use Bio::Chado::VBPopBio;
my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $projects = $schema->projects;

my $json = JSON->new->pretty;
my $verbose = 0; # print out JSON (or not)

my $isatabdir = '../../test-data/VectorBase_PopBio_ISA-Tab_full_example';
my $tempdir = "/tmp/temp-roundtrip-$$";
mkdir $tempdir;

$schema->txn_do_deferred(
		sub {

		  # read in a project
		  my $project = $projects->create_from_isatab({ directory=>$isatabdir});
		  $project->write_to_isatab({ directory=>$tempdir });

		  my $project2 = $projects->create_from_isatab({ directory=>$tempdir });
		  is_deeply($project2->as_data_structure, $project->as_data_structure, "JSON data structures the same");

		  # we were just pretending!
		  $schema->defer_exception("This is the only exception we should see.");
		}
	       );
