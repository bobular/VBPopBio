use Test::More tests => 19;
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
			   my $project_tags_type = $schema->types->project_tags;
			   ok($project_tags_type, "got the multiprops term project_tags");

			   my $project = $projects->create_from_isatab({ directory=>'../../test-data/Fallback-Species' });
			   ok($project, "parsed OK");

			   # it should have no tags!
			   is(scalar $project->tags, 0, "Fallback species project was never supposed to have any tags.");

			   # try adding a tag that doesn't exist
			   my $res1 = $project->add_tag({ term_source_ref => 'VBcv', term_accession_number => '999'});
			   is($res1, undef, "After adding a bad tag, undef expected.");
			   is(scalar @{$schema->{deferred_exceptions}}, 1, "Adding non-existent term should have thrown an exception");
			   is(scalar $project->tags, 0, "After adding a bad tag, still none.");


			   my $icemr_term = $project->add_tag({ term_source_ref => 'VBcv', term_accession_number => '0001080'}); # ICEMR
			   is($icemr_term->name, "ICEMR", "After adding a good tag, scalar result expected.");
			   my @tags2 = $project->tags;
			   is(scalar @tags2, 1, "After adding a good tag, there is one tag.");
			   is($tags2[0]->name, "ICEMR", "And it's the right one.");

			   # add a tag that isn't a project tag
			   my $res3 = $project->add_tag({ term_source_ref => 'VBcv', term_accession_number => '0001003'}); # blood meal
			   is($res3, undef, "Correctly did not load a tag from outside the subtree");
			   is(scalar @{$schema->{deferred_exceptions}}, 2, "Previous add_tag should have thrown an exception");

			   # now add a second tag
			   my $abundance_term = $project->add_tag({ term_source_ref => 'VBcv', term_accession_number => '0001085'}); # abundance
			   is($abundance_term->name, "abundance", "Name of second tag checks out.");
			   my @tags4 = $project->tags;
			   is(scalar @tags4, 2, "After adding second tag, there are two tags.");
			   is($tags4[1]->name, "abundance", "And it was added in the second position");

			   # now let's delete a tag
			   my $rip_icemr_term = $project->delete_tag($icemr_term);
			   is($rip_icemr_term->name, "ICEMR", "After deleting ICEMR tag, it was returned.");
			   is(scalar $project->tags, 1, "After the delete, there is one tag.");

			   # let's delete a tag that wasn't added
			   my $snp_chip_term = $project->delete_tag({ term_source_ref => 'VBcv', term_accession_number => '0001091'}); # SNP-chip
			   is($snp_chip_term, undef, "Undef returned when deleting tag that isn't there.");

			   # and delete the remaining abundance tag
			   my $rip_abundance_term = $project->delete_tag($abundance_term);
			   is($rip_abundance_term->name, "abundance", "Deleted abundance term");
			   is(scalar $project->tags, 0, "No tags left");

			   $schema->defer_exception("Don't worry about this exception and the one before it.");
			 });

