#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: bin/restructure_for_veupath.pl [ --dry-run ] [ --verbose ] [ --limit 20 ] --projects VBP0000nnn,VBP0000mmm
#
#        also allows comma-separated project IDs and also: --projects ALL
#
# options:
#   --dry-run              : rolls back transaction and doesn't insert into db permanently
#   --verbose              : show non-error progress logging
#   --limit N              : process max N samples per project

use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use Getopt::Long;
use utf8::all;

use aliased 'Bio::Chado::VBPopBio::Util::Multiprop';

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $cvterms = $schema->cvterms;
my $dry_run;
my $project_ids;
my $verbose;
my $limit;

GetOptions("dry-run|dryrun"=>\$dry_run,
	   "projects=s"=>\$project_ids,
           "verbose"=>\$verbose,
           "limit=i"=>\$limit,
	  );

die "need to give --projects param\n" unless (defined $project_ids);

# disable buffering of standard output so the progress update is "live"
$| = 1;

# run everything in a transaction
$schema->txn_do_deferred
  ( sub {

      # handle the projects commandline arg
      my @projects = ();
      if ($project_ids eq 'ALL') {
        @projects = $schema->projects->all;
      } else {
        foreach my $project_id (split /\W+/, $project_ids) {
          my $project = $schema->projects->find_by_stable_id($project_id);
          unless ($project) {
            warn "project $project_id not found\n";
            next;
          }
          push @projects, $project;
        }
      }

      my $done_samples = 0;
      # now loop through the projects we are processing
      foreach my $project (@projects) {
        my $project_id = $project->stable_id;
	my $num_samples = $project->stocks->count;
        print "processing $project_id ($num_samples samples)...\n";

        my $samples = $project->stocks;
	while (my $sample = $samples->next()) {

          # TO DO: map ontology terms (old->new) in sample props

          # loop through all four types of assay
          my $collections = $sample->field_collections;
          while (my $assay = $collections->next()) {
            # TO DO: handle collection protocol old->new and add extra device prop when needed

            # TO DO: map ontology terms in props
          }

          my $species_assays = $sample->species_identification_assays;
          while (my $assay = $species_assays->next()) {
            # TO DO: map protocol old->new

            # TO DO: map ontology terms in props
          }

          my $phenotype_assays = $sample->phenotype_assays;
          while (my $assay = $phenotype_assays->next()) {
            # TO DO: map protocol old->new
            # TO DO: map ontology terms in props

            # loop through phenotypes and convert them to assay props
            my $phenotypes = $assay->phenotypes;
            while (my $phenotype = $phenotypes->next()) {
              if ($phenotype->observable->name eq 'resistance to single insecticide') {
                # easier to work with $phenotype->as_data_structure
                printf "got an IR resistance attr='%s' val='%s' cval='%s' unit='%s'\n",
                  $phenotype->attr->name, $phenotype->value,
                    $phenotype->cvalue ? $phenotype->cvalue->name : '',
                      $phenotype->assay ? $phenotype->assay->name : '';
              } else {
                print "not yet handled observable=".$phenotype->observable->name."\n";
              }
            }
          }

          my $genotype_assays = $sample->genotype_assays;
          while (my $assay = $genotype_assays->next()) {
            # TO DO: map protocol old->new

            # TO DO: map ontology terms in props
          }

          # TO DO: sample manipulations??


          $done_samples++;
          last if ($limit && $done_samples >= $limit);
	}

	## $project->update_modification_date() if ($count_changed > 0);

      }
      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );

