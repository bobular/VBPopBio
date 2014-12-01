use Test::More tests => 1;

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
		  my $project = $projects->create_from_isatab({ directory=>'../../test-data/Missing-Publication-Info' });

		  is(scalar(@{$schema->{deferred_exceptions}}), 1, "exactly one deferred exception expected at this point");

		  $schema->defer_exception("This is the second exception which does the roll-back.");
		}
	       );
