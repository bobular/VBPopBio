#!/usr/bin/env perl
#                 -*- mode: cperl -*-
#
# usage: bin/create_json_for_solr.pl -dbname vb_popgen_testing_20110607 > test-samples.json
#
#
# option:
#   -limit P,Q,R,S    # for debugging - limit output to P projects, R samples, R IR phenotypes and S genotypes
#   -limit N          # same as above, same limit for all document types
#
#
## get example solr server running (if not already)
# cd /home/maccallr/vectorbase/popgen/search/apache-solr-3.5.0/example/
# screen -S solr-popgen java -jar start.jar
#
## add data like this:
# curl 'http://localhost:8983/solr/update/json?commit=true' --data-binary @test-samples.json -H 'Content-type:application/json'
#
# GitHub repo URL: https://github.com/bobular/VBPopBio/commit/c83b2d155174c247a63eca5bf8ffe5f37f27482f
#

use strict;
use warnings;
use feature 'switch';
use lib 'lib';
use Getopt::Long;
use Bio::Chado::VBPopBio;
use JSON;
use DateTime::Format::ISO8601;
use DateTime;
use Geohash;
use Clone qw(clone);
use Tie::IxHash;
use Scalar::Util qw(looks_like_number);
use PDL;

my $dbname = $ENV{CHADO_DB_NAME};
my $dbuser = $ENV{USER};
my $dry_run;
my $limit;
my $project_stable_id;

GetOptions("dbname=s"=>\$dbname,
	   "dbuser=s"=>\$dbuser,
	   "dry-run|dryrun"=>\$dry_run,
	   "limit=s"=>\$limit, # for debugging/development
	   "project=s"=>\$project_stable_id, # just one project for debugging
	  );


warn "project and limit options are not usually compatible - limit may never be reached for all Solr document types" if (defined $limit && $project_stable_id);

my ($limit_projects, $limit_samples, $limit_ir_phenotypes, $limit_genotypes);
if (defined $limit) {
  my @limits = split /\D+/, $limit;
  if (@limits == 4) {
    ($limit_projects, $limit_samples, $limit_ir_phenotypes, $limit_genotypes) = @limits;
  } else {
    ($limit_projects, $limit_samples, $limit_ir_phenotypes, $limit_genotypes) = ($limits[0], $limits[0], $limits[0], $limits[0]);
  }
}

my $dsn = "dbi:Pg:dbname=$dbname";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $dbuser, undef, { AutoCommit => 1 });
# the next line is for extra speed - but check for identical results with/without
$schema->storage->_use_join_optimizer(0);
my $stocks = $schema->stocks;
my $projects = $schema->projects;
my $assays = $schema->assays;

my $json = JSON->new->pretty; # useful for debugging
my $gh = Geohash->new();
my $done;
my $needcomma = 0;

# stops "wide character in print" warnings
binmode(STDOUT, ":utf8");

#
# debug only
#
if ($project_stable_id) {
  my $project = $projects->find_by_stable_id($project_stable_id);
  $stocks = $project->stocks;
  $assays = $project->experiments;
  $projects = $schema->projects->search({ project_id => $project->id });
}


# 'bioassay' MIRO:20000058
# because unfortunately we have used MIRO:20000100 (PCR amplification of specific alleles)
# to describe genotype assays totally unrelated to insecticide resistance
my $ir_assay_base_term = $schema->cvterms->find_by_accession({ term_source_ref => 'MIRO',
							       term_accession_number => '20000058' });

# insecticidal substance
my $insecticidal_substance = $schema->cvterms->find_by_accession({ term_source_ref => 'MIRO',
							       term_accession_number => '10000239' });

# quantitative qualifier
my $quantitative_qualifier = $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv',
							       term_accession_number => '0000702' });

my $concentration_term = $schema->cvterms->find_by_accession({ term_source_ref => 'PATO',
							       term_accession_number => '0000033' });

my $duration_term = $schema->cvterms->find_by_accession({ term_source_ref => 'EFO',
							       term_accession_number => '0000433' });

my $sample_size_term = $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv',
							       term_accession_number => '0000983' });

my $chromosomal_inversion_term = $schema->cvterms->find_by_accession({ term_source_ref => 'SO', 
                      term_accession_number => '1000030' });

my $inversion_term = $schema->cvterms->find_by_accession({ term_source_ref => 'SO',
                     term_accession_number => '1000036' });

my $genotype_term = $schema->cvterms->find_by_accession({ term_source_ref => 'SO',
                     term_accession_number => '0001027' });

my $count_unit_term = $schema->cvterms->find_by_accession({ term_source_ref => 'UO',
                     term_accession_number => '0000189' });

my $simple_sequence_length_polymorphism_term = $schema->cvterms->find_by_accession({ term_source_ref => 'SO',
										     term_accession_number => '0000207' });

my $microsatellite_term = $schema->cvterms->find_by_accession({ term_source_ref => 'SO',
								term_accession_number => '0000289' });

my $length_term = $schema->cvterms->find_by_accession({ term_source_ref => 'PATO',
							term_accession_number => '0000122' });

my $mutated_protein_term = $schema->cvterms->find_by_accession({ term_source_ref => 'IDOMAL',
								 term_accession_number => '50000004' });

my $variant_frequency_term = $schema->cvterms->find_by_accession({ term_source_ref => 'SO',
								   term_accession_number => '0001763' });

my $iso8601 = DateTime::Format::ISO8601->new;

print "[\n";

### PROJECTS ###
$done = 0;
my $study_design_type = $schema->types->study_design;
my $start_date_type = $schema->types->start_date;
my $end_date_type = $schema->types->end_date;
my $date_type = $schema->types->date;

#print "iterating through projects... @andy: @done: remove this later @remove\n"; @needlater?

while (my $project = $projects->next) {
  my $stable_id = $project->stable_id;
  my @design_terms = map { $_->cvterms->[1] } $project->multiprops($study_design_type);
  my @publications = $project->publications;
  my $document = ohr(
		    label => $project->name,
		    id => $stable_id,
		    accession => $stable_id,
		    # type => 'project', # doesn't seem to be in schema
		    bundle => 'pop_project',
		    bundle_name => 'Project',
		    site=> 'Population Biology',
	            url => '/popbio/project/?id='.$stable_id,
		    entity_type => 'popbio',
		    entity_id => $project->id,
		    description => $project->description ? $project->description : '',
		    date => iso8601_date($project->public_release_date),
		    authors => [
				map { $_->description } $project->contacts
			       ],
		    study_designs => [
				      map { $_->name } @design_terms
				     ],
		    study_designs_cvterms => [
					      map { flattened_parents($_) } @design_terms
					     ],
		    pubmed => [ map { "PMID:$_" } grep { $_ } map { $_->miniref } @publications ],
		    publications_status => [ map { $_->status->name } @publications ],
		    publications_status_cvterms => [ map { flattened_parents($_->status) } @publications ],

		   );
  my $json_text = $json->encode($document);
  chomp($json_text);
  print ",\n" if ($needcomma++);
  print qq!$json_text\n!;

  last if (defined $limit && ++$done >= $limit_projects);
}

#
# store phenotype values for later normalisation
#

my %phenotype_signature2values; # measurement_type/assay/insecticide/concentration/c_units/duration/d_units/species => [ vals, ... ]
my %phenotype_id2value; # phenotype_stable_ish_id => un-normalised value
my %phenotype_id2signature; # phenotype_stable_ish_id => signature

# @done: make the limit stop the whole script once all: done_samples, done_ir_phenotypes, done_genotypes (in future) are finished) // @bob:showed me @andy:shown by bob // @2015-08-15 

### SAMPLES ###
my $done_samples = 0;
my $done_ir_phenotypes = 0;
my $done_genotypes = 0;

while (my $stock = $stocks->next) {
  my $stable_id = $stock->stable_id;

  die "stock with db id ".$stock->id." does not have a stable id" unless ($stable_id);

  my @collection_protocol_types = map { $_->type } map { $_->protocols->all } $stock->field_collections;
  my $latlong = stock_latlong($stock); # only returns coords if one site
  my $stock_best_species = $stock->best_species();
  my $fc = $stock->field_collections->first;

  my @field_collections = $stock->field_collections;

  my @phenotype_assays = $stock->phenotype_assays;
  my @phenotypes = map { $_->phenotypes->all } @phenotype_assays;

  my @genotype_assays = $stock->genotype_assays;
  my @genotypes = map { $_->genotypes->all } @genotype_assays;

  my $document = ohr(
		    label => $stock->name,
		    id => $stable_id,
		    # type => 'sample', # doesn't seem to be in schema
		    accession => $stable_id,
		    bundle => 'pop_sample',
		    bundle_name => 'Sample',
	  	    site => 'Population Biology',
		    url => '/popbio/sample/?id='.$stable_id,
		    entity_type => 'popbio',
		    entity_id => $stock->id,
		    description => $stock->description || join(' ', ($stock_best_species ? $stock_best_species->name : ()), $stock->type->name, ($fc ? $fc->geolocation->summary : ())),

		    sample_type => $stock->type->name,
		    sample_type_cvterms => [ flattened_parents($stock->type) ],

		    collection_protocols => [ map { $_->name } @collection_protocol_types ],
		    collection_protocols_cvterms => [ map { flattened_parents($_) } @collection_protocol_types ],

		    has_geodata => (defined $latlong ? 'true' : 'false'),
		    (defined $latlong ? ( geo_coords_fields($latlong) ) : ()),

		    geolocations => [ map { $_->geolocation->summary } @field_collections ],
		    geolocations_cvterms => [ remove_gaz_crap( map { flattened_parents($_)  } map { multiprops_cvterms($_->geolocation, qr/^GAZ:\d+$/) } @field_collections ) ],

		    genotypes =>  [ map { ($_->description, $_->name) } @genotypes ],
		    genotypes_cvterms => [ map { flattened_parents($_)  } map { ( $_->type, multiprops_cvterms($_) ) } @genotypes ],

		    phenotypes =>  [ map { $_->name } @phenotypes ],
		    phenotypes_cvterms => [ map { flattened_parents($_)  } grep { defined $_ } map { ( $_->observable, $_->attr, $_->cvalue, multiprops_cvterms($_) ) } @phenotypes ],

		    ($stock_best_species ? (
					    species => [ $stock_best_species->name ],
					    species_cvterms => [ flattened_parents($stock_best_species) ]
					   ) :
		                           ( species => [ 'Unknown' ] ) ),

		    annotations => [ map { $_->as_string } $stock->multiprops ],
		    annotations_cvterms => [ map { flattened_parents($_) } multiprops_cvterms($stock) ],

		    projects => [ map { quick_project_stable_id($_) } $stock->projects ],

		    # used to be plain 'date' from any assay
		    # now it's collection_date if there's an unambiguous collection
		    (defined $fc ? ( assay_date_fields($fc) ) : () ),

		    pubmed => [ map { "PMID:$_" } multiprops_pubmed_ids($stock) ],
		   );

  if (!defined $limit || ++$done_samples <= $limit_samples){
    # print the sample
    my $json_text = $json->encode($document);
    chomp($json_text);
    print ",\n" if ($needcomma++);
    print qq!$json_text\n!;
  }

  # now handle phenotypes

  # reuse the sample document data structure
  # to avoid having to do a lot of cvterms fields over and over again
  foreach my $phenotype_assay (@phenotype_assays) {
    last if (defined $limit && $done_ir_phenotypes >= $limit_ir_phenotypes);

    # is it a phenotype that we can use?
    my @protocol_types = map { $_->type } $phenotype_assay->protocols->all;

    if (grep { $_->id == $ir_assay_base_term->id ||
	       $ir_assay_base_term->has_child($_) } @protocol_types) {

      # yes we have an INSECTICIDE RESISTANCE BIOASSAY

      # cloning is safer and simpler (but more expensive) than re-using $document
      # $document is the sample document
      my $doc = clone($document);

      my $assay_stable_id = $phenotype_assay->stable_id;

      # always change these fields
      $doc->{bundle} = 'pop_sample_phenotype';
      $doc->{bundle_name} = 'Sample phenotype';

      delete $doc->{phenotypes};
      delete $doc->{phenotypes_cvterms};

      # NEW fields
      $doc->{phenotype_type_s} = "insecticide resistance";
      $doc->{protocols} = [ map { $_->name } @protocol_types ];
      $doc->{protocols_cvterms} = [ map { flattened_parents($_) } @protocol_types ];

      foreach my $phenotype ($phenotype_assay->phenotypes) {
      	
      	#print "\t\t\tphenotype... @andy @done: remove later after  @remove\n";

		my $phenotype_stable_ish_id = $stable_id.".".$phenotype->id;
		# alter fields
		$doc->{id} = $phenotype_stable_ish_id;
		$doc->{url} = '/popbio/assay/?id='.$assay_stable_id; # this is closer to the phenotype than the sample page
		$doc->{label} = $phenotype->name;
		$doc->{accession} = $assay_stable_id;
		$doc->{description} = "IR phenotype '".$phenotype->name."' for $stable_id";
		# NEW fields

		# figure out what kind of value
		my $value = $phenotype->value;
		my $value_unit = $phenotype->unit;

		# clean up some trailing non-digits if the value contains digits
		# this is to deal with VBA0170859 having a value of 0.012ppm AND proper units
		$value =~ s/\D+$// if (defined $value && defined $value_unit);
		# let's clean leading and trailing whitespace while we are at it
		if (defined $value) {
		  $value =~ s/^\s+//; $value =~ s/\s+$//;
		}

		if (defined $value && looks_like_number($value)) {
		  $doc->{phenotype_value_f} = $value;

		  if (defined $value_unit) {
		    $doc->{phenotype_value_unit_s} = $value_unit->name;
		    $doc->{phenotype_value_unit_cvterms} = [ flattened_parents($value_unit) ];
		  }

		  my $value_type = phenotype_value_type($phenotype); # e.g. mortality rate, LT50 etc
		  if (defined $value_type) {
		    $doc->{phenotype_value_type_s} = $value_type->name;
		    $doc->{phenotype_value_type_cvterms} = [ flattened_parents($value_type) ];

		  } else {
		    warn "no value type for phenotype of $assay_stable_id\n";
		  }

		  # to do: insecticide + concentrations + duration
		  # die "to do...";

		  my ($insecticide, $concentration, $concentration_unit, $duration, $duration_unit, $sample_size, $errors) =
		    assay_insecticides_concentrations_units_and_more($phenotype_assay);

		  die "assay $assay_stable_id had fatal issues: $errors\n" if ($errors);

		  if (defined $insecticide) {
		    $doc->{insecticide_s} = $insecticide->name;
		    $doc->{insecticide_cvterms} = [ flattened_parents($insecticide) ];

		    if (defined $concentration && looks_like_number($concentration) && defined $concentration_unit) {
		      $doc->{concentration_f} = $concentration;
		      $doc->{concentration_unit_s} = $concentration_unit->name;
		      $doc->{concentration_unit_cvterms} = [ flattened_parents($concentration_unit) ];
		    } else {
		      warn "no/incomplete/corrupted concentration data for $assay_stable_id\n";
		    }

		  } else {
		    warn "no insecticide for $assay_stable_id !!!\n";
		  }

		  if (defined $duration && defined $duration_unit) {
		    $doc->{duration_f} = $duration;
		    $doc->{duration_unit_s} = $duration_unit->name;
		    $doc->{duration_unit_cvterms} = [ flattened_parents($duration_unit) ];
		  } else {
		    # warn "no/incomplete duration data for $assay_stable_id\n";
		  }

		  if (defined $sample_size) {
		    $doc->{sample_size_i} = $sample_size;
		  }

		  # phenotype_cvterms (singular)
		  $doc->{phenotype_cvterms} = [ map { flattened_parents($_)  } grep { defined $_ } ( $phenotype->observable, $phenotype->attr, $phenotype->cvalue, multiprops_cvterms($phenotype) ) ];

		  if (!defined $limit || ++$done_ir_phenotypes<=$limit_ir_phenotypes) {
		    my $json_text = $json->encode($doc);
		    chomp($json_text);
		    print ",\n" if ($needcomma++);
		    print qq!$json_text\n!;
		  }

		  # collate the values for each unique combination of protocol, insecticide, ...
		  my $phenotype_signature =
		    join "/",
		      map { $_ // '-' } # convert undefined to '-'
			$doc->{phenotype_value_type_s}, $doc->{phenotype_value_unit_s};

	#		  join(":", @{$doc->{protocols}}),
	#		    $doc->{insecticide_s},
	#		      1*$doc->{concentration_f}, $doc->{concentration_unit_s},
	#			1*$doc->{duration_f}, $doc->{duration_unit_s},
	#			  $doc->{species}->[0];

		  push @{$phenotype_signature2values{$phenotype_signature}}, $value;
		  $phenotype_id2value{$phenotype_stable_ish_id} = $value;
		  $phenotype_id2signature{$phenotype_stable_ish_id} = $phenotype_signature;

		}
      }
    }

  }

  # same for genotypes
  foreach my $genotype_assay (@genotype_assays) {
    last if (defined $limit && $done_genotypes >= $limit_genotypes);
    my $assay_stable_id = $genotype_assay->stable_id;
    my @protocol_types = map { $_->type } $genotype_assay->protocols->all;
    foreach my $genotype ($genotype_assay->genotypes) {
      my ($genotype_name, $genotype_value, $genotype_subtype, $genotype_unit); # these vars are "undefined" to start with
      my $genotype_type = $genotype->type; # cvterm/ontology term object

      # check if this genotype's type is the same as 'chromosomal inversion' or a child of it.
      if ($genotype_type->id == $chromosomal_inversion_term->id ||
        $chromosomal_inversion_term->has_child($genotype_type)) {

        # now loop through each "multiprop" property object (this is the data displayed in the right-hand sub-table in the genotypes list in the web application)
        # and see if we can get out the exact data we need - name and count

        # loop through various properties of the genotype object, looking for: "genotype_name" and "genotype_count" properties as unique markers that we actually have a "chromosomal inversion" "@genotype type"
        foreach my $prop ($genotype->multiprops) {
          my @prop_terms = $prop->cvterms;
          $genotype_name = $prop->value if ($prop_terms[0]->id == $inversion_term->id);
          $genotype_value = $prop->value if ($prop_terms[0]->id == $genotype_term->id && $prop_terms[1]->id == $count_unit_term->id);
        }
	$genotype_subtype = 'chromosomal inversion';
      } elsif ($genotype_type->id == $simple_sequence_length_polymorphism_term->id ||
	       $simple_sequence_length_polymorphism_term->has_child($genotype_type)) {
	# scan props for microsat name and length
	foreach my $prop ($genotype->multiprops) {
          my @prop_terms = $prop->cvterms;
	  $genotype_name = $prop->value if ($prop_terms[0]->id == $microsatellite_term->id);
          $genotype_value = $prop->value if ($prop_terms[0]->id == $length_term->id);
	}
	$genotype_subtype = 'microsatellite';
      } elsif ($mutated_protein_term->has_child($genotype_type)) {
	# these are ontology-defined mutant allele counts/frequencies
	# they are probably not to be confused with SNP genotype data from Ensembl when it comes to Solr...
	$genotype_name = $genotype_type->name;
	foreach my $prop ($genotype->multiprops) {
          my @prop_terms = $prop->cvterms;
          $genotype_value = $prop->value if ($prop_terms[0]->id == $count_unit_term->id ||
					     $prop_terms[0]->id == $variant_frequency_term->id);
	  $genotype_unit = $prop_terms[-1];
	}
	die "mutated protein genotype has no units" unless defined $genotype_unit;
	$genotype_subtype = 'mutated protein';
      }
      if (defined $genotype_name && defined $genotype_value && defined $genotype_subtype) {

	# we have one of the supported genotypes with all required information
	# do all the Solr document processing and printing inside this block

	# cloning is safer and simpler (but more expensive) than re-using $document
	# $document is the sample document
	my $doc = clone($document);

	# always change these fields
	$doc->{bundle}      = 'pop_sample_genotype';
	$doc->{bundle_name} = 'Sample genotype';

	delete $doc->{genotypes};
	delete $doc->{genotypes_cvterms};

	# NEW fields
	$doc->{genotype_type_s}   = $genotype_subtype;
	$doc->{protocols}         = [ map { $_->name } @protocol_types ];
	$doc->{protocols_cvterms} = [ map { flattened_parents($_) } @protocol_types ];

	my $genotype_stable_ish_id = $stable_id.".".$genotype->id;
	# alter fields
	$doc->{id} = $genotype_stable_ish_id;
	$doc->{url} = '/popbio/assay/?id='.$assay_stable_id; # this is closer to the phenotype than the sample page
	$doc->{label} = $genotype->name;
	$doc->{accession} = $assay_stable_id;
	$doc->{description} = "$genotype_subtype genotype '".$genotype->description."' for $stable_id";

	$doc->{genotype_cvterms} = [ map { flattened_parents($_) } grep { defined $_ } ( $genotype->type, multiprops_cvterms($genotype) ) ];

	$doc->{genotype_name_s} = $genotype_name;

	given($genotype_subtype) {
	  when('chromosomal inversion') {
	    $doc->{genotype_inverted_allele_count_i} = $genotype_value;
	  }
	  when('microsatellite') {
	    $doc->{genotype_microsatellite_length_i} = $genotype_value;
	  }
	  when('mutated protein') {
	    $doc->{genotype_mutated_protein_value_f} = $genotype_value;
	    $doc->{genotype_mutated_protein_unit_s} = $genotype_unit->name;
	    $doc->{genotype_mutated_protein_unit_cvterms} = [ flattened_parents($genotype_unit) ];
	  }
	}

	# Printing out a doc
	if (!defined $limit || ++$done_genotypes<=$limit_genotypes) {
	  # print out the genotype doc (cloned from $document)
	  my $json_text = $json->encode($doc);
	  chomp($json_text);
	  print ",\n" if ($needcomma++);
	  print qq!$json_text\n!;
	}
      }
    }
  }

  last if (defined $limit &&
	   $done_samples >= $limit_samples &&
	   $done_ir_phenotypes >= $limit_ir_phenotypes &&
	   $done_genotypes >= $limit_genotypes);
}


#
# create a set of normaliser functions for each signature
#
my %phenotype_signature2normaliser;
foreach my $phenotype_signature (keys %phenotype_signature2values) {
  my $values = pdl(@{$phenotype_signature2values{$phenotype_signature}});

  # when inverted == 1, low values mean the insecticide is working
  my $inverted = ($phenotype_signature =~ /^(LT|LC)/) ? 1 : 0;

  my ($min, $max) = ($values->pct(0.02), $values->pct(0.98));
  my $range = $max - $min;

  if ($range) {
    $phenotype_signature2normaliser{$phenotype_signature} =
      sub {
	my $val = shift;
	# squash outliers
	$val = $min if ($val<$min);
	$val = $max if ($val>$max);
	# now rescale
	$val -= $min;
	$val /= $range;
	$val = 1-$val if ($inverted);
	return $val;
      };
  }
}


#
# add the normalised/rescaled phenotype values to existing docs
#

foreach my $phenotype_stable_ish_id (keys %phenotype_id2signature) {
  my $phenotype_signature = $phenotype_id2signature{$phenotype_stable_ish_id};
  my $normaliser = $phenotype_signature2normaliser{$phenotype_signature};
  if ($normaliser) {
    my $rescaled = $normaliser->($phenotype_id2value{$phenotype_stable_ish_id});
    my $n = scalar @{$phenotype_signature2values{$phenotype_signature}};

    my $json_text = $json->encode(ohr(
				     id => $phenotype_stable_ish_id,
				     phenotype_rescaled_value_f => { set => $rescaled },
				     phenotype_rescaling_signature_s => { set => $phenotype_signature },
				     phenotype_rescaling_count_i => { set => $n }
				    )
				  );
    chomp($json_text);
    print ",\n" if ($needcomma++);
    print qq!$json_text\n!;

  }
}


# the commit is needed to resolve the trailing comma
print qq!]\n!;

# returns just the 'proper' cvterms for all multiprops
# of the argument
# optional filter arg: regexp to match the ontology accession, e.g. ^GAZ:\d+$
sub multiprops_cvterms {
  my ($object, $filter) = @_;
  $filter //= qr/^\w+:\d+$/;
  return grep { $_->dbxref->as_string =~ $filter } map { $_->cvterms } $object->multiprops;
}

# returns a list of pubmed ids (or empty list)
# if any multiprop comment value contains /pubmed/i and ends with (\d+)$
sub multiprops_pubmed_ids {
  my $object = shift;
  return map { $_->value =~ /pubmed.+?(\d+)$/i } grep { ($_->cvterms)[0]->name eq 'comment'  } $object->multiprops;
}

# returns $lat, $long
sub stock_latlong {

  my $stock = shift;

  foreach my $experiment ($stock->field_collections) {
    if ($stock->field_collections->count == 1) {
      my $geo = $experiment->nd_geolocation;
      if (defined $geo->latitude && defined $geo->longitude) {
	return ( join ",", $geo->latitude, $geo->longitude );
      }
    }
  }
  return undef;
}

#NOT USED#
# returns date of first assay with a date
sub stock_date {
  my $stock = shift;
  foreach my $assay ($stock->nd_experiments) {
    my $date = assay_date($assay);
    return $date if ($date); # already iso8601 from assay_date
  }
  return undef;
}


#NOT USED#
# returns single date string
sub assay_date {
  my $assay = shift;
  my @start_dates = $assay->multiprops($start_date_type);
  if (@start_dates == 1) {
    return iso8601_date($start_dates[0]->value);
  }
  my @dates = $assay->multiprops($date_type);
  if (@dates == 1) {
    return iso8601_date($dates[0]->value);
  }
  return undef;
}

# returns key=>value data for collection_date
# 1. collection_date => always an iso8601 date for the date or start_date
# 2. collection_date_range => a DateRangeField with the Chado-resolution date or [start_date TO end_date]
# 3. collection_season => One or more DateRangeField values in the year 1600 (an arbitrary leap year) used for seasonal search
#
# by Chado-resolution we mean "2010-10" will refer automatically to a range including the entire month of October 2010
#
sub assay_date_fields {
  my $assay = shift;

  my @dates = $assay->multiprops($date_type);
  if (@dates == 1) {
    my $date = $dates[0]->value;
    return (
	    collection_date => iso8601_date($date),
	    collection_date_range => $date,
	    collection_season => season($date),
	   );
  } else {
    my @start_dates = $assay->multiprops($start_date_type);
    my @end_dates = $assay->multiprops($end_date_type);
    if (@start_dates == 1 && @end_dates == 1) {
      my $start_date = $start_dates[0]->value;
      my $end_date = $end_dates[0]->value;

      # convert to datetime to check correct order
      # swap them if start > end
      my ($start_dt, $end_dt) = ($iso8601->parse_datetime($start_date), $iso8601->parse_datetime($end_date));
      if (DateTime->compare($start_dt, $end_dt) > 0) {
	($start_date, $end_date) = ($end_date, $start_date);
      }


      return  ($start_date eq $end_date) ? (
					    collection_date => iso8601_date($start_date),
					    collection_date_range => $start_date,
					    collection_season => season($start_date),
					   ) :
					   (
					    collection_date => iso8601_date($start_date),
					    collection_date_range => "[$start_date TO $end_date]",
					    collection_season => season($start_date, $end_date),
					   );

    }
  }
  return ();
}

#
sub season {
  my ($start_date, $end_date) = @_;
  if (!defined $end_date) {
    # a single date or low-resolution date (e.g. 2014) will be returned as-is
    # and converted by Solr into a date range as appropriate
    $start_date =~ s/^\d{4}/1600/;
    return [ $start_date ];
  } else {
    # we already parsed them in the calling function, but never mind...
    my ($start_dt, $end_dt) = ($iso8601->parse_datetime($start_date), $iso8601->parse_datetime($end_date));

    # is start to end range >= 1 year?
    if ($start_dt->add( years => 1 )->compare($end_dt) <= 0) {
      return "1600";
    }

    my ($start_month, $end_month) = ($start_dt->month, $end_dt->month);

    # change the Chado-sourced date strings to year 1600
    $start_date =~ s/^\d{4}/1600/;
    $end_date =~ s/^\d{4}/1600/;

    if ($start_month <= $end_month) {
      return [ "[$start_date TO $end_date]" ];
    } else {
      # range spans new year, so return two ranges
      return [ "[$start_date TO 1600-12-31]",
	       "[1600-01-01 TO $end_date]" ];
    }
  }
}

# converts poss truncated string date into ISO8601 Zulu time (hacked with an extra Z for now)
sub iso8601_date {
  my $string = shift;
  my $datetime = $iso8601->parse_datetime($string);
  if (defined $datetime) {
    return $datetime->datetime."Z";
  }
}

#DEPRECATED
# returns an array of cvterms
# definitely want has child only (not IS also) because
# the insecticidal_substance term is used as a multiprop "key"
sub assay_insecticides {
  my $assay = shift;
  return grep { $insecticidal_substance->has_child($_) } map { $_->cvterms } $assay->multiprops;
}

# returns these scalars
# 1. insecticide (cvterm)
# 2. concentration (number)
# 3. concentration unit (cvterm)
# 4. duration (number)
# 5. duration unit (cvterm)
# 6. sample size (number - no units needed)
# 7. error (string or empty/undef)
sub assay_insecticides_concentrations_units_and_more {
  my $assay = shift;
  my $insecticide;
  my $concentration;
  my $unit;
  my $duration;
  my $duration_unit;
  my $sample_size;
  my @errors;

  foreach my $multiprop ($assay->multiprops) {
    my @cvterms = $multiprop->cvterms;
    foreach my $cvterm (@cvterms) {
      if ($insecticidal_substance->has_child($cvterm)) {
	push @errors, "already got an insecticide" if (defined $insecticide);
	$insecticide = $cvterm;
      } elsif ($cvterm->id == $concentration_term->id && defined $multiprop->value) {
	push @errors, "already got a concentration" if (defined $concentration);
	$concentration = $multiprop->value;
	$unit = $cvterms[-1]; # units are always last
      }

      if ($cvterm->id == $duration_term->id && defined $multiprop->value) {
	push @errors, "already got a duration" if (defined $duration);
	$duration = $multiprop->value;
	$duration_unit = $cvterms[-1];
      }

      if ($cvterm->id == $sample_size_term->id && defined $multiprop->value) {
	push @errors, "already got a sample size" if (defined $sample_size);
	$sample_size = $multiprop->value;
      }
    }
  }
  return ($insecticide, $concentration, $unit, $duration, $duration_unit, $sample_size, join ";", @errors);
}


# returns an array of (name, accession, name, accession, ...)
# now cached
my %term_id_to_flattened_parents;
sub flattened_parents {
  my $term = shift;
  my $id = $term->id;
  $term_id_to_flattened_parents{$id} ||= [ map { ( $_->name, $_->cvtermsynonyms->get_column('synonym')->all, $_->dbxref->as_string ) } ($term, $term->recursive_parents_same_ontology) ];
  return @{$term_id_to_flattened_parents{$id}};
}

#
# cached quick version
#
my %project_id_to_stable_id;
sub quick_project_stable_id {
  my $project = shift;
  my $id = $project->id;
  return $project_id_to_stable_id{$id} ||= $project->stable_id;
}


#
# returns list of all key-value pairs for geo-coordinates
#
# arg 1 = latlong comma separated string
#
# uses global $gh object
#
sub geo_coords_fields {
  my $latlong = shift;
  my ($lat, $long) = split /,/, $latlong;
  die "some unexpected problem with latlog arg to geo_coords_fields\n"
    unless (defined $lat && defined $long);

  my $geohash = $gh->encode($lat, $long, 6);

  return (geo_coords => $latlong,
	  geohash_6 => $geohash,
	  geohash_5 => substr($geohash, 0, 5),
	  geohash_4 => substr($geohash, 0, 4),
	  geohash_3 => substr($geohash, 0, 3),
	  geohash_2 => substr($geohash, 0, 2),
	  geohash_1 => substr($geohash, 0, 1));
}


#
# phenotype_value_type
#
# pass a phenotype object, returns the term of the attribute or observable that is a child of 'quantitative qualifier'
#

sub phenotype_value_type {
  my $phenotype = shift;

  my $term;
  if ((defined ($term = $phenotype->observable) &&
      ($term->id == $quantitative_qualifier->id ||
       $quantitative_qualifier->has_child($term)))
      || (defined ($term = $phenotype->attr) &&
      ($term->id == $quantitative_qualifier->id ||
       $quantitative_qualifier->has_child($term)))) {
    return $term;
  }
  return;
}

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

sub remove_gaz_crap {
  my @result;
  my $state = 1;
  foreach my $element (@_) {
    $state = 0 if ($element eq 'continent' ||
		   $element eq 'geographical location' ||
		   $element eq 'Oceans and Seas'
		  );
    push @result, $element if ($state);
    $state = 1 if ($element eq 'GAZ:00000448');
  }
  return @result;
}
