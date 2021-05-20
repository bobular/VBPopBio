#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: CHADO_DB_NAME=my_chado_instance bin/split_restructure_commands.pl --limit-samples 50 --prefix dry-run-errors/ | sort -R | parallel --jobs .jobs
#
# will run the restructure command with --limit 50 and send STDERR to dry-run-errors/VBP0000001 etc
#
# TO DO: needs to pass isatab directory prefix when running without --limit-samples
#
# NOTE: can be made much quicker by adding this index in pgsql
# create index dbxrefprop_TEMP_BOB on dbxrefprop (value);
#

use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use JSON;
use Getopt::Long;

my $limit_samples = 0;
my $error_file_prefix = "TEMP-stderr-";
my $isatab_prefix = "TEMP-isatab-";

GetOptions("limit_samples=i"=>\$limit_samples,
           "error_file_prefix|prefix=s"=>\$error_file_prefix,
           "isatab-prefix|isatab_prefix=s"=>\$isatab_prefix,
	  );

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });

# $schema->storage->debug(1);

# should speed things up
# $schema->storage->_use_join_optimizer(0);

$| = 1;

my $projects = $schema->projects->ordered_by_id;
my $done_projects = 0;
my @commands;
while (my $project = $projects->next) {
  my $stable_id = $project->stable_id;
  printf "bin/restructure_for_veupath.pl --projects %s --limit %d --error $error_file_prefix%s --dump-isatab --isatab-prefix %s\n", $stable_id, $limit_samples, $stable_id, $isatab_prefix;
}
