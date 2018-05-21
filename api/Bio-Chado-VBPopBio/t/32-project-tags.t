use Test::More tests => 18;

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

		  # it should have no tags!
		  my $tags = $project->tags;
		  is($tags, undef, "Fallback species project was never supposed to have any tags.");

		  my $res1 = $project->add_tag("bad format");
		  is($res1, undef, "After adding a bad tag, undef expected.");
		  is($project->tags, undef, "After adding a bad tag, still none.");

		  my $res2 = $project->add_tag("good-format");
		  is($res2, "good-format", "After adding a good tag, scalar result expected.");
		  is($project->tags, "good-format", "After adding a good tag, it's there.");

		  my $res3 = $project->add_tag("good-format");
		  is($res3, undef, "After adding a duplicate tag, undef expected.");

		  my $res4 = $project->add_tag("second-tag");
		  is($res4, "good-format,second-tag", "After adding a new tag, string expected.");
		  my @tags2 = $project->tags;
		  is(scalar @tags2, 2, "now two tags in array result");

		  my $res5 = $project->remove_tag("non-existent");
		  is($res5, undef, "Expected undef when trying to remove non-existent tag");

		  my $res6 = $project->remove_tag("good-format");
		  is($res6, "second-tag", "remaining tag is second-tag");
		  my @tags1 = $project->tags;
		  is(scalar @tags1, 1, "now one tag in array result");

		  # now remove the final remaining tag
		  my $res7 = $project->remove_tag("second-tag");
		  is($res7, undef, "no more tags left");
		  my @tags0 = $project->tags;
		  is(scalar @tags0, 0, "Same zero result from project->tags");

		  # just check we can add some back again
		  my $res8 = $project->tags("a,b,c,d,e,f,g,h");
		  isnt($res8, undef, "return value OK after adding 8 tags");
		  my @tags8 = $project->tags;
		  is(scalar @tags8, 8, "and got 8 from project->tags");

		  # now check they are parsed from ISA-Tab OK

		  $project = $projects->create_from_isatab({ directory=>'../../test-data/Project-Tags' });

		  ok($project, "parsed Project-Tags ISA-Tab OK");

		  # it should have three tags!
		  my @tags3 = $project->tags;
		  is(scalar @tags3, 3, "Project-Tags ISA-Tab yielded three tags");

		  # we were just pretending!
		  $schema->defer_exception("This is the only exception we should see.");
		}
	       );
