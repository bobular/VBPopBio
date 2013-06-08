#!/usr/bin/env perl
#                                                       -*- mode: cperl -*-
#
# usage: bin/update_vis_configs.pl [ --wipe-all --dry-run -dbname my_chado_db -dbuser henry ] input_file
#
# The following two options also allowed in input file (input file always has precedence)
#
# option defaults: dbname = $ENV{CHADO_DB_NAME}
#                  dbuser = $ENV{USER}
#
# --dry-run prints out (unofficial) project JSON and rolls back transaction
# --wipe-all resets all projects to have a vis_configs empty array
#
#
# input_file follows this format
# http://search.cpan.org/dist/Config-General/General.pm#CONFIG_FILE_FORMAT
#
# see accompanying example in bin/update_vis_configs-example.cfg
#
#


use strict;
use warnings;
use lib 'lib';  # this is so that I don't have to keep installing BCNA for testing
use Getopt::Long;
use Bio::Chado::VBPopBio;
use Config::General;
use JSON; # for debugging only


my $dbname = $ENV{CHADO_DB_NAME};
my $dbuser = $ENV{USER};
my $dry_run;
my $wipe_all;

GetOptions("dbname=s"=>\$dbname,
	   "dbuser=s"=>\$dbuser,
	   "dry-run|dryrun"=>\$dry_run,
	   "wipe-all"=>\$wipe_all,
	  );

my ($input_file) = @ARGV;
my $conf = new Config::General(-ConfigFile => $input_file,
			       -SplitPolicy => 'equalsign',
			      );
my %config = $conf->getall;

$dbuser = $config{dbuser} || $dbuser;
$dbname = $config{dbname} || $dbname;

my $dsn = "dbi:Pg:dbname=$dbname";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $dbuser, undef, { AutoCommit => 1 });
my $projects = $schema->projects;
my $json = JSON->new->pretty; # useful for debugging

$schema->txn_do(
		sub {
		  if ($wipe_all) {
		    foreach my $project ($projects->all) {
		      $project->vis_configs('');
		    }
		  }

		  while (my ($project_external_id, $project_data) = each %{$config{project}}) {
		    my $project = $projects->find_by_external_id($project_external_id)
		      || die "can't find project by external '$project_external_id'... aborting!\n";

		    my $existing_json = $project->vis_configs;
		    my $vis_json = $project_data->{vis_configs};

		    if (defined $vis_json) {
		      # silently skip project if JSON text is identical
		      if (!defined $existing_json || $vis_json ne $existing_json) {
			# do a sanity test here - check JSON is OK before loading it
			my $data = $json->decode($vis_json);
			if (ref($data) eq 'ARRAY') {
                          print "updating vis_configs for $project_external_id\n";
			  $project->vis_configs($vis_json);
			  $project->update_modification_date();
			} else {
			  die "aborting due to JSON syntax error in:\n$vis_json\n";
			}
		      }
		    } else {
		      my $existing_data = $json->decode($existing_json);
		      if (ref($existing_data) eq 'ARRAY' && @{$existing_data} > 0) {
			warn "no vis config for $project_external_id - are you sure you want to erase its visualisations?\n";
		      }
		    }

		  }
		  if ($dry_run) {
		    warn "dry-run, rolling back...\n";
		    $schema->txn_rollback;
		  }
		});
