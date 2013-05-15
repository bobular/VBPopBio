#!/usr/bin/perl -w

#
# usage: bin/this_script.pl
#
# (no args)
#
#
#

use strict;
use Carp;

use lib '../api/Bio-Chado-VBPopBio/lib'; # use the latest local uninstalled API
use Bio::Chado::VBPopBio;

#use JSON;
#my $json = JSON->new->pretty;

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $projects = $schema->projects;

#
# load some complex test data
#

$schema->txn_do_deferred(
    sub {
	warn "full example...\n";
	my $project = $projects->create_from_isatab({ directory=>'../test-data/VectorBase_PopBio_ISA-Tab_full_example' });
    });

$schema->txn_do_deferred(
    sub {
	warn "derived...\n";
	my $project = $projects->create_from_isatab({ directory=>'../test-data/VectorBase_PopBio_ISA-Tab_derived-from_example' });
    });

$schema->txn_do_deferred(
    sub {
	warn "re-use VBA...\n";
my $project = $projects->create_from_isatab({ directory=>'../test-data/Test-ISA-Tab-pre-existing-VBA-ids' });
    });

$schema->txn_do_deferred(
    sub {
	warn "re-use VBS...\n";
	my $project = $projects->create_from_isatab({ directory=>'../test-data/Test-ISA-Tab-pre-existing-VBS-ids' });
    });

#
# NEAFSEY
#

# commented out because not in the git repository

$schema->txn_do_deferred(
    sub {
# 	warn "Neafsey...\n";
#	my $neafsey = $projects->create_from_isatab({ directory=>'../../data/isa-tab/VB_PopBio_ISA-Tab_2010-Neafsey-M-S-Bamako' });
    });
