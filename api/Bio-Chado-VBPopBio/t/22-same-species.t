use Test::More tests => 3;

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
		  my $project = $projects->create_from_isatab({ directory=>'../../test-data/Same-Species-Bug' });

		  isnt($project, undef, "project shouldn't be undef");

		  my $sample = $project->stocks->first;

		  isnt($sample, undef, "first sample shouldn't be undef");

		  is($sample->best_species->name, "Anopheles nuneztovari", "species is Anopheles nuneztovari");

		  $schema->defer_exception("This is the exception which does the roll-back.");
		}
	       );
