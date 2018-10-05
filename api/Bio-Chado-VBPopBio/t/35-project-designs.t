use Test::More tests => 6;
use strict;
use JSON;
use Bio::Chado::VBPopBio;
my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $projects = $schema->projects;
my $json = JSON->new->pretty;
my $verbose = 0;		# print out JSON (or not)
$schema->txn_do_deferred(
			 sub {
			   my $project = $projects->create_from_isatab({ directory=>'../../test-data/Project-Tags' });
			   ok($project, "parsed OK");

			   my @design_terms = $project->designs();
			   is(scalar @design_terms, 2, "has two designs");
			   is($design_terms[0]->name, "strain or line design", "design term is strain or line design");

			   my $data = $project->as_data_structure(0);
			   is(scalar @{$data->{designs}}, 2, "data structure also two designs");
			   is($data->{designs}[1]{name}, "pathogenicity design", "data structure also returns correct term name");
			   is($data->{designs}[1]{accession}, "EFO:0001761", "data structure also returns correct term accession");


			   $schema->defer_exception("Don't worry about this exception and the one before it.");
			 });

