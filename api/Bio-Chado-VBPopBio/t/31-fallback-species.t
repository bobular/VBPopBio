use Test::More tests => 7;

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
		  my $project = $projects->create_from_isatab({ directory=>'../../test-data/Fallback-Species' });


		  ok($project, "parsed OK");

		  my @samples = $project->stocks->all;

		  is(scalar @samples, 2, "got two samples");

		  is($samples[0]->best_species($project)->name, "Anopheles nuneztovari", "Sample one is nuneztovari");

		  my ($species_term, $reason) = $samples[1]->best_species();
		  is($species_term, undef, "Sample two species is undefined - because we didn't pass project to best_species");
		  is($reason->name, 'unknown', "Sample two reason is unknown - because we didn't pass project to best_species");

		  ($species_term, $reason) = $samples[1]->best_species($project);
		  is($species_term->name, "Anopheles funestus sensu lato", "Sample two is fallback");
		  is($reason->name, "project default", "fallback reason");

		  # we were just pretending!
		  $schema->defer_exception("This is the only exception we should see.");
		}
	       );
