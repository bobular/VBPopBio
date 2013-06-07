#!/usr/bin/env perl -w

#
# usage: ./this_script.pl
#
# (no args)
#
#
# POST-PROCESSING to remove other experiments which are dragging in too many stocks (mostly FCs)
#
# DELETE FROM nd_experiment_project where nd_experiment_project_id in (select nd_experiment_project_id from nd_experiment_project ep join nd_experiment e on (ep.nd_experiment_id = e.nd_experiment_id) join cvterm type on (type.cvterm_id = e.type_id) join nd_experiment_protocol epro on (epro.nd_experiment_id=e.nd_experiment_id) join nd_protocol pro on (epro.nd_protocol_id = pro.nd_protocol_id) where project_id in (XXX,XXX,XXX,XXX) and pro.name != 'AgPopGenBase:inversion_karyotyping');
#
# field collections don't join in the above query because they (or at least, some) have no protocol (it seems)
#
# DELETE FROM nd_experiment_project where nd_experiment_project_id in (select nd_experiment_project_id from nd_experiment_project ep join nd_experiment e on (ep.nd_experiment_id = e.nd_experiment_id) join cvterm type on (type.cvterm_id = e.type_id) where project_id in (XXX,XXX,XXX,XXX) and type.name = 'field collection');
# 
#
use strict;
use Carp;
use lib 'lib';  # this is so that I don't have to keep installing BCNA for testing

use Bio::Chado::VBPopBio;
use JSON;
# we need this so we can pass an iterable $stocks object to the metaproject create method
use Iterator::Simple qw/iter/;
# add a count method
{ package Iterator::Simple::Iterator;
  use Iterator::Simple qw/list/;
  use Clone::Closure qw/clone/;
  sub count { return scalar @{list(clone(shift))}; }
}

my $json = JSON->new->pretty;

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $metaprojects = $schema->metaprojects;

my $dbxrefs = $schema->dbxrefs;

# this is an experimental factor
my $sampling_time = $dbxrefs->find({ accession => '0000689', version => '', 'db.name' => 'EFO' },
				   { join => 'db' })->cvterm;
die "couldn't find 'sampling time' cvterm\n" unless (defined $sampling_time);

$schema->txn_do(
		sub {
		  foreach my $year (2002 .. 2007) {
		    # search for the constituent stocks and project(s)
		    my $stocks = $schema->stocks->search_by_project({ 'project.name' => 'UC Davis/UCLA population dataset' })
		      ->search_by_nd_experimentprop({ 'type.name' => 'start date',
						      'nd_experimentprops.value' => { like => "$year%" } });


		    # filter (slowly) in perl because the search/join to two different nd_experiments is too horrendous
		    my @has_2L = grep { grep { grep { $_->name eq 'AgPopGenBase:inversion_karyotyping' } $_->nd_protocols and grep { grep { $_->value eq '2L' } $_->genotypeprops } $_->genotypes } $_->genotype_assays } $stocks->all;

		    my $n_stocks = scalar @has_2L;
		    next unless ($n_stocks);

		    my $projects = $schema->projects->search({ name => 'UC Davis/UCLA population dataset' });

		    my $name = "UC Davis/UCLA population data subset with 2L karyotype from $year";
		    my $description = $projects->first->description." This is a subset of the data: mosquitoes collected during $year that have 2L karyotypes.";

		    warn "Making metaproject $name ($description) from $n_stocks stocks\n";
		    # make the metaproject
		    my $metaproject = $metaprojects->create_with( { name => $name,
								    description => $description,
								    stocks => iter(\@has_2L),
								    projects => $projects->reset,
								    # no experimental_factors
								    });
		  }
		  # $schema->txn_rollback;
		});
