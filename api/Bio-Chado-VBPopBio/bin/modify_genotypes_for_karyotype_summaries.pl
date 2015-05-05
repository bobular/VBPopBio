#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: CHADO_DB_NAME=my_chado_instance -inversions 2La,2Rjbcdu  bin/create-genotypes-for-karyotype-summaries.pl VBP0000003
#
#
#
#
# options:
#
#   --inversions           : comma separated list of chromosomes and their assayed inversions
#                            this is so that we can assign zero count for uninverted inversions
#                            THIS ASSUMES THAT ALL INVERSIONS WERE ASSAYED SUCCESSFULLY WITHIN A PROJECT
#                            but the notation used (e.g. 2R+/+) makes it difficult to assume otherwise.
#
#   --dry-run              : rolls back transaction and doesn't insert into db permanently
#
#   --limit 2              : only does 2 genotype_assays
#
# Authors: Andy Brockman (started in 2014), Bob MacCallum (completed in 2015)
#

use strict;
use warnings;
use lib 'lib';
use Bio::Chado::VBPopBio;
use Getopt::Long;
use Data::Dumper;
use aliased 'Bio::Chado::VBPopBio::Util::Multiprops';
use Tie::IxHash;

# CONNECT TO DATABASE
my $dsn    = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });


# DEFAULT ARGS
my $dry_run;
my $inversions = "2La,2Rjbcdu";
my $limit;

# CMD ARGS
GetOptions( "dry-run|dryrun"=>\$dry_run,
	    "inversions=s"=>\$inversions,
	    "limit=i"=>\$limit,
	  );

my $project_id = shift @ARGV;

my %chr2inversions; # 2R => [ 'j', 'b', 'c', 'd', 'u' ]

foreach my $part (split /,/, $inversions) {
  my ($chr, $inversions) = split(/(?<=[RLX])/,$part);
  $chr2inversions{$chr} = [ split //, $inversions ];
}

#
# Initiate Some useful Hashes
#
my %inversionCount_to_zygosity=( 0 => 'homozygous non-inverted',
			      1 => 'heterozygous inverted',
			      2 => 'homozygous inverted' );


#
# some cvterms
#
my $paracentric_inversion_term =
  $schema->cvterms->find_by_accession({ term_source_ref => 'SO',
					term_accession_number => '1000047'} );
my $inversion_term =
  $schema->cvterms->find_by_accession({ term_source_ref => 'SO',
					term_accession_number => '1000036'} );
my $genotype_term =
  $schema->cvterms->find_by_accession({ term_source_ref => 'SO',
					term_accession_number => '0001027'} );
my $chromosome_arm_term =
  $schema->cvterms->find_by_accession({ term_source_ref => 'SO',
					term_accession_number => '0000105'} );
my $karyotype_term =
  $schema->cvterms->find_by_accession({ term_source_ref => 'EFO',
					term_accession_number => '0004426'} );
my $count_term =
  $schema->cvterms->find_by_accession({ term_source_ref => 'UO',
					term_accession_number => '0000189'} );


# TRANSACTION WRAPPER
$schema->txn_do_deferred(

    sub{

      #--------------------------------------------------------
      #   ALL GENOTYPE ASSAYS
      #       E.G. of inversion genotype assay, i.e. a genotype assay with 100% inversion types, i.e.e. an examplar genotype assay we want to apply our magic to inversion genotypes
      #           my $genotype_assay = $schema->genotype_assays->find_by_stable_id('VBA0011667') # has two inversion genotypes
      #--------------------------------------------------------

      my $project = $schema->projects->find_by_stable_id($project_id);
      my $genotype_assays = $project->genotype_assays;

      #--------------------------------------------------------
      # CHROMOSOMAL INVERSION ONTOLOGY
      #   used in the loop to check if a genotype falls into the category of “inversion”
      #--------------------------------------------------------

      my $num_done = 0;
      while (my $genotype_assay = $genotype_assays->next) {
	my $genotype_assay_stable_id = $genotype_assay->stable_id;
	#--------------------------------------------------------
	# TEST ASSAY WORTHINESS
	#   assay is worthy if #genotypes within that are inversion type == total #genotypes in the assay
	#--------------------------------------------------------

	my $genotypes      = $genotype_assay->genotypes;
	my $num_inversions = 0;

	while (my $genotype = $genotypes->next) {
	  if ( $genotype->type->id == $paracentric_inversion_term->id ) {
	    $num_inversions++;
	  }
	}

	# Q: DOES GENOTYPE_ASSAY PASS THE TEST?
	if ($num_inversions == $genotypes->count) {
	  #--------------------------------------------------------
	  # LOOP THROUGH GENOTYPES
	  #   reformatting them
	  #   adding/removing to database
	  #--------------------------------------------------------

	  $genotypes->reset;
	  my @new_arrangements; # added
	  my @new_genotypes; # these will be added
	  my @rip_genotypes; # these will die
	  while (my $genotype = $genotypes->next) {
	    push @rip_genotypes, $genotype;
	    #--------------------------------------------------------
	    # REFORMATTING
	    #--------------------------------------------------------
                                                 # e.g.
	    my $karyotype = $genotype->name;     #   2La/a

	    #-------------------------------------------------------- 
	    # SPLIT
	    #   split incoming inversion haplotype into <CHROMOSOME & ARM> <HAPLOTYPE>
	    #   lookbehind allows placing delimiter back into the split, /(?<=[RL])/ 
	    #   @split_karyotype = split(/(?<=[RL])/,'2Rjcu/jcu'); 
	    #--------------------------------------------------------

	    my ($chrome_and_arm, $haplotype) = split(/(?<=[RLX])/,$karyotype);
	    # e.g. ('2R', 'jcu/jcu')


	    # 1. make the new "arrangement" genotype

	    my $arrangement = $schema->genotypes->find_or_create({
								  name => $karyotype,
								  uniquename => "$genotype_assay_stable_id:arrangement:$karyotype",
								  description => "$chrome_and_arm karyotype $karyotype",
								  type => $karyotype_term,
								 });

	    Multiprops->add_multiprops_from_isatab_characteristics
	      ( row => $arrangement,
		prop_relation_name => 'genotypeprops',
		characteristics => ohr ( 'Characteristics [chromosome_arm (SO:0000105)]' =>
					 { value => $chrome_and_arm },
					 'Characteristics [genotype (SO:0001027)]' =>
					 { value => $karyotype }
				      )
	      );

	    push @new_arrangements, $arrangement;


	    # 2. individual inversion genotypes with counts

	    foreach my $inversion_letter (@{$chr2inversions{$chrome_and_arm}}) {
	      # count how many times inverted
	      my $i_count = () = $haplotype =~ /$inversion_letter/g;
	      my $g_name = "$chrome_and_arm$inversion_letter";
	      my $genotype = $schema->genotypes->find_or_create({
								 name => $g_name,
								 uniquename => "$genotype_assay_stable_id:$g_name:$i_count",
								 description => "$g_name $inversionCount_to_zygosity{$i_count}",
								 type => $paracentric_inversion_term,
								});

	      Multiprops->add_multiprops_from_isatab_characteristics
		( row => $genotype,
		  prop_relation_name => 'genotypeprops',
		  characteristics => ohr( 'Characteristics [inversion (SO:1000036)]' =>
					  { value => $g_name },
					  'Characteristics [genotype (SO:0001027)]' =>
					  { value => $i_count,
					    unit => { term_source_ref => 'UO',
						      term_accession_number => '0000189', # count unit
						    }
					  } )
		);

	      push @new_genotypes, $genotype;
	    }
	  }

	  map { $_->delete } @rip_genotypes;
	  foreach my $new_genotype (@new_arrangements, @new_genotypes) {
	    my $assay_link = $new_genotype->find_or_create_related('nd_experiment_genotypes',
								   { nd_experiment => $genotype_assay });
	  }

	} elsif ($num_inversions > 0) {
	  warn "MIXED GENOTYPES in genotype assay $genotype_assay_stable_id\n";
	}

	last if ($limit && ++$num_done >= $limit);
      }

      $schema->defer_exception("dry-run option - rolling back") if ($dry_run); # Not sure how this works exactly

    }
);

warn "WARNING: --limit option used without --dry-run - $project_id is only partially done!\n" if ($limit && !$dry_run);


#
# ohr = ordered hash reference
#
# return order-maintaining hash reference
# with optional arguments as key-value pairs
#
sub ohr {
  my $ref = { };
  tie %$ref, 'Tie::IxHash', @_;
  return $ref;
}
