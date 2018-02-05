#!/usr/bin/env perl
# -*- mode: cperl -*-
#
# finds genotype assays with the specified --old_reference_genome gggg
# and optionally --old_region rrrr with --new_reference_genome hhhh and
# --new_region ssss
#
# usage: CHADO_DB_NAME=my_chado_instance bin/update_genome_references.pl --old_reference_genome Anopheles_gambiae --list
#
# options:
#   --project stable-id           : which project to update (defaults to all)
#
#   --old_reference_genome gggg   : assay props from ISA-Tab column Characteristics [reference_genome (SO:0001505)] containing this
#   --new_reference_genome hhhh   : will be replaced by this (old and new required)
#
#   --old_region rrrr             : matches to this
#   --new_region ssss             : replaced by this (old and new required)
#
#   --list                        : will list all reference_genome and region data from the database
#
#   --dry-run                     : rolls back transaction and doesn't insert into db permanently
#
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
my $cvterms = $schema->cvterms;
my $dry_run;
my $json_file;
my $json = JSON->new->pretty;
my $quiet;
my $project_id;
my $list;
my ($old_reference_genome, $new_reference_genome);
my ($old_region, $new_region);



GetOptions("dry-run|dryrun"=>\$dry_run,
	   "project=s"=>\$project_id,
	   "list"=>\$list,
	   "old_reference_genome=s"=>\$old_reference_genome,
	   "new_reference_genome=s"=>\$new_reference_genome,
	   "old_region=s"=>\$old_region,
	   "new_region=s"=>\$new_region,
	  );

my ($isatab_dir) = @ARGV;

# should speed things up
$schema->storage->_use_join_optimizer(0);

my $ref_type = $cvterms->find_by_accession({term_source_ref => 'SO', term_accession_number=>'0001505'});
my $region_type = $cvterms->find_by_accession({term_source_ref => 'SO', term_accession_number=>'0000703'});

$schema->txn_do_deferred
  ( sub {

      my $genotype_assays = $schema->genotype_assays;
      if ($project_id) {
	my $project = $projects->find_by_stable_id($project_id);
	unless ($project) {
	  die "can't find project $project_id in database\n";
	}
	$genotype_assays = $project->genotype_assays;
      }

      printf "num genotype assays to check %d\n", $genotype_assays->count;

      my %assays; # reference_genome => region => [ $assays... ]

      while (my $assay = $genotype_assays->next) {
	# easy way to test if this is a high throughput assay
	if ($assay->vcf_file) {
	  my @multiprops = $assay->multiprops;
	  # needs at least two multiprops to contain reference and region
	  if (@multiprops >= 2) {
	    my ($ref, $region);
	    foreach my $multiprop (@multiprops) {
	      my $prop_key_id = $multiprop->cvterms->[0]->cvterm_id;
	      if ($prop_key_id == $ref_type->cvterm_id) {
		$ref = $multiprop->value;
	      } elsif ($prop_key_id == $region_type->cvterm_id) {
		$region = $multiprop->value;
	      }
	    }

	    if ($ref && $region && $project_id) {
	      push @{$assays{$ref}{$region}}, $assay;
	    }
	  }
	}
      }

      if ($list) {
	# print them out most numerous first
	foreach my $ref (sort { keys %{$assays{$b}} <=> keys %{$assays{$a}} } keys %assays) {
	  foreach my $region (sort { @{$assays{$ref}{$b}} <=> @{$assays{$ref}{$a}} } keys %{$assays{$ref}}) {
	    printf "%-15s\t%-15s\t%d\n",
	      $ref, $region, scalar @{$assays{$ref}{$region}};
	  }
	}
      }

      if ($old_reference_genome) {
	my @regions = $old_region ? ($old_region) : keys %{$assays{$old_reference_genome}};
	foreach my $region (@regions) {
	  foreach my $assay (@{$assays{$old_reference_genome}{$region}}) {

	    my $assay_stable_id = $assay->stable_id;
	    my $update_done;

	    if ($new_reference_genome) {
	      # find the raw prop (not multiprop) with
	      # value eq $old_reference_genome
	      my $props = $assay->search_related('nd_experimentprops', { value => $old_reference_genome });
	      if ($props->count == 1) {
		my $prop = $props->first;
		$prop->value($new_reference_genome);
		$prop->update;
		$update_done++;
		print "$assay_stable_id $old_reference_genome -> $new_reference_genome\n";
	      } else {
		die "PROBLEM: found %d props for $old_reference_genome\n", $props->count;
	      }
	    }

	    if ($old_region && $new_region) {
	      my $props = $assay->search_related('nd_experimentprops', { value => $old_region });
	      if ($props->count == 1) {
		my $prop = $props->first;
		$prop->value($new_region);
		$prop->update;
		$update_done++;
		print "$assay_stable_id $old_region -> $new_region\n";
	      } else {
		die "PROBLEM: found %d props for $old_region\n", $props->count;
	      }
	    }

	    $assay->projects->first->update_modification_date() if ($update_done);
	  }
	}

      }

      warn "finished processing\n";

      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );

