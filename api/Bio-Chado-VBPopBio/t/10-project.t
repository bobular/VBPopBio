use Test::More tests => 23;

use Bio::Chado::VBPopBio;
my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });

my $projects = $schema->projects();

isa_ok($projects, 'Bio::Chado::VBPopBio::ResultSet::Project', "resultset correct class");


# check that we can create and delete a project
my $result =
  $schema->txn_do_deferred(sub {
		    my $proj_extID_type = $schema->types->project_external_ID;

		    my $project = $projects->create
		      ({
			name => 'test project unique name 123',
			description => 'should not exist',
		       });
		    $project->external_id('1970-Smith-test');
		    $project->submission_date("2012-11");
		    $project->public_release_date("2015-05");

		    ok(defined $project, "project object defined");
		    is($project->external_id, '1970-Smith-test', "external id");
		    is($project->submission_date, '2012-11', "submission date");
		    is($project->public_release_date, '2015-05', "public release date");
		    ok($projects->looks_like_stable_id($project->stable_id), "stable ID looks ok");

		    my $project2 = $projects->create
		      ({
			name => 'test project unique name 12345',
			description => 'should not exist',
		       });
		    $project2->external_id('1970-Smith-test2');
		    $project2->submission_date('2010b'); # should throw an expected exception

		    like($project2->stable_id, qr/^VBP\d+$/, "second stable ID looks ok");
		    isnt($project->stable_id, $project2->stable_id, "two project stable IDs are different");

		    my $project3 = $projects->create
		      ({
			name => 'test project unique name 0000',
			description => 'should not exist',
		       });
		    $project3->external_id('1970-Smith-test3');

		    ok($projects->looks_like_stable_id($project3->stable_id), "third stable ID looks ok");
		    isnt($project3->stable_id, $project2->stable_id, "second and third are different");

		    is($project3->stable_id, $project3->stable_id, "two calls return same stable id");

		    my $stable_id3 = $project3->stable_id;
		    $project3->delete;

		    # quick test for find_by_stable_id
		    is($projects->find_by_stable_id($stable_id3), undef, "shouldn't find it");

		    my $project3b = $projects->create
		      ({
			name => 'test project unique name 0000',
			description => 'should not exist',
		       });
		    $project3b->external_id('1970-Smith-test3');

		    is($stable_id3, $project3b->stable_id, "deleted and recreated project has same stable id");

		    # test find_by_external_id
		    my $p2 = $projects->find_by_external_id('1970-Smith-test2');
		    isa_ok($p2, "Bio::Chado::VBPopBio::Result::Project", "found by external id");

		    # test find_by_stable_id
		    my $p3 = $projects->find_by_stable_id($stable_id3);
		    isa_ok($p3, "Bio::Chado::VBPopBio::Result::Project", "found by stable id");
		    is($p3->id, $project3b->id, "same internal id");
		    is($p3->external_id, $project3b->external_id, "same external id");

		    like($project->creation_date, qr/^\d{4}-\d{2}-\d{2}$/, "project has a sane creation date");
		    is($project2->creation_date, $p2->creation_date, "project2 and p2 creation dates the same");

		    my $fail_date = eval { $project->last_modified_date };
		    is($fail_date, undef, "not allowed to get last_modified_date before update_modification_date");
		    my $last_modified = $project->update_modification_date();
		    is($project->last_modified_date, $last_modified, "last_modified_date seems to work");

		    like($project->last_modified_date, qr/^\d{4}-\d{2}-\d{2}$/, "project has a sane modification date");

		    is(scalar(@{$schema->{deferred_exceptions}}), 1, "one expected deferred exceptions");
		    # we were just pretending! roll back:
		    $schema->defer_exception("This is the only exception we should see.");
		  });


