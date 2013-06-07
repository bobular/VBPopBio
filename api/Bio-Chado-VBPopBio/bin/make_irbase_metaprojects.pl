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

my $dbxrefs = $schema->dbxrefs;

# this is an experimental factor
my $sampling_time = $dbxrefs->find({ accession => '0000689', version => '', 'db.name' => 'EFO' },
				   { join => 'db' })->cvterm;
die "couldn't find 'sampling time' cvterm\n" unless (defined $sampling_time);

my ($measurement, $insecticide, $concs, $range);

$schema->txn_do(
		sub {
		  foreach my $opt ({
				     measurement => '% mortality',
				     insecticide => 'permethrin',
				     range => '0.25-1%',
				     concs => [ '1.00%', '1%', '0.900%', '0.75%', '0,75%', '0.25%', '0,25%', '0.250%' ]
				    },

				   {
				     measurement => '% mortality',
				     insecticide => 'DDT',
				     range => '4%',
				     concs => [ '4%', '4,00%', '4.00%', '4.0%', '4.000%' ]
				   },

				   {
				     measurement => '% mortality',
				     insecticide => 'malathion',
				     range => '5%',
				     concs => [ '5,00%', '5%', '5.00%', '5.000%', '5.0%' ]
				   },

				   {
				     measurement => '% mortality',
				     insecticide => 'dieldrin',
				     range => '0.4%',
				     concs => [ '0,40%', '0.40%', '0.4%', '0.400%' ]
				   },

				   {
				     measurement => '% mortality',
				     insecticide => 'temephos',
				     range => '0.012-0.04mg/l',
				     concs => [ '0.012mg/l', '0.04 mg/liter', '0.02mg/l' ]
				   },

				   {
				     measurement => '% mortality',
				     insecticide => 'propoxur',
				     range => '0.1-0.3%',
				     concs => [ '0.300%', '0.1%', '0.10%', '0,10%', '0.100%' ]
				   },

				   {
				     measurement => '% mortality',
				     insecticide => 'fenitrothion',
				     range => '0.5-1%',
				     concs => [ '1%', '0.500%', '1,00%', '1,0%', '1.00%', '1.000%', '1.0%' ]
				   },

				  ) {
		    make_metaproject($opt);
		  }

		  # $schema->txn_rollback;
		});

sub make_metaproject {
  my ($opt) = @_;

  warn "Starting $opt->{measurement} $opt->{range} $opt->{insecticide}\n";

  my $stocks = $schema->stocks->search_by_phenotype({ 'observable.name' => $opt->{measurement} })->search_by_nd_protocolprops(2, { 'type.name' => 'insecticide', 'type_2.name' => 'concentration' } )->search_by_nd_experimentprops(2, { 'type_3.name' => $opt->{insecticide}, 'nd_protocolprops.rank' => { '=' => \'nd_experimentprops.rank' }, 'nd_protocolprops_2.rank' => { '=' => \'nd_experimentprops_2.rank' }, 'nd_experimentprops_2.value' => { in => $opt->{concs} } })->search({}, {distinct=>1});

# doesn't work this way round!
#  my $stocks = $schema->stocks->search_by_nd_protocolprops(2, { 'type.name' => 'insecticide', 'type_2.name' => 'concentration' } )->search_by_nd_experimentprops(2, { 'type_3.name' => $opt->{insecticide}, 'nd_protocolprops.rank' => { '=' => \'nd_experimentprops.rank' }, 'nd_protocolprops_2.rank' => { '=' => \'nd_experimentprops_2.rank' }, 'nd_experimentprops_2.value' => { in => $opt->{concs} } })->search_by_phenotype({ 'observable.name' => $opt->{measurement} })->search({}, {distinct=>1});

  # crudely filter out projects which are already meta-projects
  # ideally we should use a left outer join query on the project_relationship table test for null subject
  # but that seems to require a whole new relationship to be defined
  my $projects = $stocks->projects->search({ 'project.name' => { 'not like' => 'Meta%' }});

  my $n_projects = $projects->count;
  my $name = "Meta-analysis: $opt->{measurement} after exposure to $opt->{range} $opt->{insecticide}";
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
