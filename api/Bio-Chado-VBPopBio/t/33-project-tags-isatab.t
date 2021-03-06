use Test::More tests => 7;
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

			   # it should have two tags
			   my @tags = $project->tags;
			   is(scalar @tags, 2, "Two tags loaded from ISA-Tab");
			   is($tags[0]->name, "insecticide resistance phenotyping", "First tag correct name");
			   is($tags[1]->name, "insecticide resistance genotyping", "First tag correct name");

			   my $data = $project->as_data_structure(0);
			   is(scalar @{$data->{tags}}, 2, "data structure also two tags");
			   is($data->{tags}[1]{name}, "insecticide resistance genotyping", "data structure also returns correct term name");
			   is($data->{tags}[1]{accession}, "VBcv:0001088", "data structure also returns correct term accession");

			   $schema->defer_exception("This is the only exception we should see.");
			 });

