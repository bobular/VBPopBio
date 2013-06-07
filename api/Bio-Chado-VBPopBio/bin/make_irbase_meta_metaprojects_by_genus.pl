#!/usr/bin/env perl -w

#
# usage: ./this_script.pl
#
# (no args)
#
# figure out conc ranges with
#
# $insecticide = 'DDT';
#
# $eprops = $schema->resultset('NaturalDiversity::NdExperimentprop')->search({ 'type.name' => 'density unit', 'type_2.name' => $insecticide }, { join => [ 'type', { 'nd_experiment' => { nd_experimentprops => 'type' } } ] } );
#
# %c=(); map { $c{$_}++ } $eprops->get_column('value')->all;
# foreach $val (sort { $c{$b}<=>$c{$a} } keys %c) {
#  print "$c{$val} instances of $val\n";
# }
#

use strict;
use Carp;
use lib 'lib';  # this is so that I don't have to keep installing BCNA for testing

use Bio::Chado::VBPopBio;
use JSON;

my $json = JSON->new->pretty;

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $metaprojects = $schema->metaprojects;

# $schema->storage->debug(1);

my $dbxrefs = $schema->dbxrefs;

# this is an experimental factor
my $sampling_time = $dbxrefs->find({ accession => '0000689', version => '', 'db.name' => 'EFO' },
				   { join => 'db' })->cvterm;
die "couldn't find 'sampling time' cvterm\n" unless (defined $sampling_time);

my ($measurement, $insecticide, $concs, $range);

$schema->txn_do(
		sub {
		  foreach my $opt (
											 {
												project_name => 'Meta-analysis: % mortality after exposure to 0.25-1% permethrin',
												genus => 'Anopheles'
											 },
											 {
												project_name => 'Meta-analysis: % mortality after exposure to 0.25-1% permethrin',
												genus => 'Aedes'
											 },

											 {
												project_name => 'Meta-analysis: % mortality after exposure to 4% DDT',
												genus => 'Anopheles'
											 },

											 {
												project_name => 'Meta-analysis: % mortality after exposure to 4% DDT',
												genus => 'Aedes'
											 },

											 {
												project_name => 'Meta-analysis: % mortality after exposure to 4% DDT',
												genus => 'Culex'
											 },

											 {
												project_name => 'Meta-analysis: % mortality after exposure to 5% malathion',
												genus => 'Anopheles'
											 },
											 {
												project_name => 'Meta-analysis: % mortality after exposure to 5% malathion',
												genus => 'Aedes'
											 },
											 {
												project_name => 'Meta-analysis: % mortality after exposure to 5% malathion',
												genus => 'Culex'
											 },

											 {
												project_name => 'Meta-analysis: % mortality after exposure to 0.4% dieldrin',
												genus => 'Anopheles'
											 },

											 {
												project_name => 'Meta-analysis: % mortality after exposure to 0.1-0.3% propoxur',
												genus => 'Anopheles'
											 },
											 {
												project_name => 'Meta-analysis: % mortality after exposure to 0.1-0.3% propoxur',
												genus => 'Aedes'
											 },

											 {
												project_name => 'Meta-analysis: % mortality after exposure to 0.5-1% fenitrothion',
												genus => 'Anopheles'
											 },
											 {
												project_name => 'Meta-analysis: % mortality after exposure to 0.5-1% fenitrothion',
												genus => 'Aedes'
											 },

											 {
												project_name => 'Meta-analysis: % mortality after exposure to 0.012-0.04mg/l temephos',
												genus => 'Aedes'
											 },

											) {
		    make_metaproject($opt);
		  }

		  # $schema->txn_rollback;
		});

sub make_metaproject {
  my ($opt) = @_;

  warn "Starting $opt->{project_name} $opt->{genus}\n";

	my $project = $schema->projects->find({ name => $opt->{project_name} });

  my $stocks = $project->stocks->search_by_species_identification_assay_result({ 'type.name' => { like => "$opt->{genus} %" }})->search({}, {distinct=>1});

  # crudely filter out projects which are already meta-projects
  # ideally we should use a left outer join query on the project_relationship table test for null subject
  # but that seems to require a whole new relationship to be defined
  my $projects = $stocks->projects->search({ 'project.name' => { 'not like' => 'Meta%' }});

  my $n_projects = $projects->count;
  my $name = $project->name()." in mosquitoes from the genus $opt->{genus}";
  my $description = "This is a meta-experiment containing insecticide resistance data from different studies.";

  my $n_stocks = $stocks->count;
  warn "Making metaproject $name ($description) from $n_stocks stocks ($n_projects projects)\n";

  # make the metaproject
  my $metaproject = $metaprojects->create_with( { name => $name,
						  description => $description,
						  stocks => $stocks->reset,
						  projects => $projects->reset,
						  # no experimental_factors
						});
  return $metaproject;
}
