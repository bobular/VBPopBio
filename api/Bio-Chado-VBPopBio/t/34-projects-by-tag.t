use Test::More tests => 5;
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
			   my $project1 = $projects->create_from_isatab({ directory=>'../../test-data/Fallback-Species' });
			   my $icemr_term = $project1->add_tag({ term_source_ref => 'VBcv', term_accession_number => '0001080'}); # ICEMR
			   my $ir_term = $project1->add_tag({ term_source_ref => 'VBcv', term_accession_number => '0001087'}); # IR phenotyping

			   # this one already has insecticide resistance tags
			   my $project2 = $projects->create_from_isatab({ directory=>'../../test-data/Project-Tags' });

			   my $projects_ir = $projects->search_by_tag($ir_term);
			   is($projects_ir->count, 2, "found two projects with IR phenotyping tag");

			   my $projects_icemr = $projects->search_by_tag($icemr_term);
			   is($projects_icemr->count, 1, "found one project with ICEMR tag");

#			   my $projects_nih = $projects->search_by_tag({ term_source_ref => 'VBcv', term_accession_number => '0001078'}); # NIH, grandparent of ICEMR
#			   is($projects_nih->count, 1, "Should have found ICEMR project with NIH tag");

			   my $projects_abundance = $projects->search_by_tag({ term_source_ref => 'VBcv', term_accession_number => '0001085'}); # abundance
			   is($projects_abundance->count, 0, "Should be zero projects with abundance tag");

			   my $projects_arthropoda = $projects->search_by_tag({ term_source_ref => 'VBsp', term_accession_number => '0004000'}); # Arthropoda
			   is($projects_arthropoda->count, 0, "Should be no results from non-tag Arthropoda");
			   is(scalar @{$schema->{deferred_exceptions}}, 1, "Adding non-tag term should have thrown an exception");

			   $schema->defer_exception("Don't worry about this exception and the one before it.");
			 });

