#!/usr/bin/env perl
# -*- mode: cperl -*-
#
# deletes and reloads only the publications and contacts
#
# TO DO: study design types (seems technically tricky :-| )
#        description (easier!)
#
#
# usage: CHADO_DB_NAME=my_chado_instance bin/update_project_metadata.pl --project VBP0000123 ../path/to/ISA-Tab-directory
#
# options:
#   --project stable-id    : which project to update
#   --dry-run              : rolls back transaction and doesn't insert into db permanently
#

use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use JSON;
use Getopt::Long;
use utf8::all;
use Bio::Parser::ISATab 0.05;


my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $projects = $schema->projects;
my $dry_run;
my $json_file;
my $json = JSON->new->pretty;
my $quiet;
my $project;

GetOptions("dry-run|dryrun"=>\$dry_run,
	   "project=s"=>\$project,
	  );

my ($isatab_dir) = @ARGV;

die "must give isatab directory on commandline\n" unless (-d $isatab_dir);

die "must provide --project ID on commandline\n" unless ($project);

# should speed things up
$schema->storage->_use_join_optimizer(0);

$schema->txn_do_deferred
  ( sub {

      my $project = $projects->find_by_stable_id($project);
      unless ($project) {
	die "can't find project $project in database\n";
      }

      my $parser = Bio::Parser::ISATab->new(directory=>$isatab_dir);
      my $isa = $parser->parse();
      my $study = $isa->{studies}[0];

      # delete publications
      my $rip_count = $project->publications->count;
      warn "deleting $rip_count publications...\n";
      map { $_->delete} $project->publications;

      my $publications = $schema->publications;
      foreach my $study_publication (@{$study->{study_publications}}) {
	my $publication = $publications->find_or_create_from_isatab($study_publication);
	$project->add_to_publications($publication) if ($publication);
	warn "added publication\n";
      }

      my $rip_contacts = $project->contacts->count;
      warn "deleting $rip_contacts contacts...\n";
      map { $_->delete } $project->contacts;

      my $contacts = $schema->contacts;
      foreach my $study_contact (@{$study->{study_contacts}}) {
	my $contact = $contacts->find_or_create_from_isatab($study_contact);
	$project->add_to_contacts($contact) if ($contact);
	warn "added contact\n";
      }

      warn "updating modification time stamp\n";
      $project->update_modification_date();

      warn "finished processing\n";

      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );

