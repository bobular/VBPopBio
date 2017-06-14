#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: CHADO_DB_NAME=my_chado_instance bin/rename_sample.pl VBSnnnnnnn OLD_NAME NEW_NAME
#
# options:
#   --dry-run              : rolls back transaction and doesn't insert into db permanently

use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use Getopt::Long;
use utf8::all;

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $samples = $schema->stocks;
my $dry_run;

GetOptions("dry-run|dryrun"=>\$dry_run,
	  );

my ($sample_id, $old_name, $new_name) = @ARGV;

$schema->txn_do_deferred
  ( sub {

      my $sample = $samples->find_by_stable_id($sample_id);
      if ($sample) {
	# change the actual name
	if ($sample->name eq $old_name) {
	  $sample->name($new_name);
	  $sample->update;
	} else {
	  $schema->defer_exception("sample name was ".$sample->name." but expected $old_name");
	}

	# find the dbxref prop that stores the external_id for stable_id tracking
	my @dbxrefprops = grep { $_->type->name eq 'sample external ID' } $sample->dbxref->dbxrefprops->all;
	if (@dbxrefprops == 1) {
	  my $prop = $dbxrefprops[0];
	  if ($prop->value eq $old_name) {
	    $prop->value($new_name);
	    $prop->update();
	  } else {
	    $schema->defer_exception("dbxref prop was ".$prop->value." but expected $old_name");
	  }
	} else {
	  $schema->defer_exception("found too many/few dbxrefprops for sample external ID (@dbxrefprops)");
	}
      } else {
	$schema->defer_exception("can't find sample '$sample_id'");
      }

      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );

