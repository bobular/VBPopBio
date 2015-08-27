#!/usr/bin/env perl
#                 -*- mode: cperl -*-
#
# usage: bin/create_json_for_solr.pl -dbname vb_popgen_testing_20110607 > test-samples.json
#
#
#
#
## get example solr server running (if not already)
# cd /home/maccallr/vectorbase/popgen/search/apache-solr-3.5.0/example/
# screen -S solr-popgen java -jar start.jar
#
## add data like this:
# curl 'http://localhost:8983/solr/update/json?commit=true' --data-binary @test-samples.json -H 'Content-type:application/json'
#
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
	   "limit=i"=>\$limit, # for debugging/development
	   "project=s"=>\$project_stable_id, # just one project for debugging
	  );

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

my $iso8601 = DateTime::Format::ISO8601->new;

my $study_design_type = $schema->types->study_design;
my $start_date_term_id = $schema->types->start_date->id;
my $end_date_term_id = $schema->types->end_date->id;
my $date_term_id = $schema->types->date->id;

print "[\n";

### PROJECTS ###
$done = 0;

while (my $project = $projects->next) {
  my $stable_id = $project->stable_id;
  my @design_terms = map { $_->cvterms->[1] } $project->multiprops($study_design_type);
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
		    pubmed => [ map { "PMID:$_" } grep { $_ } map { $_->miniref } $project->publications ],
		   );
  my $json_text = $json->encode($document);
  chomp($json_text);
  print ",\n" if ($needcomma++);
  print qq!$json_text\n!;

  last if ($limit && ++$done >= $limit);
}

#
# store phenotype values for later normalisation
#

my %phenotype_signature2values; # measurement_type/assay/insecticide/concentration/c_units/duration/d_units/species => [ vals, ... ]
my %phenotype_id2value; # phenotype_stable_ish_id => un-normalised value
my %phenotype_id2signature; # phenotype_stable_ish_id => signature


### SAMPLES ###
$done = 0;
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
		    (defined $latlong ? ( collection_date => assay_date($fc) ) : ()),

		    pubmed => [ map { "PMID:$_" } multiprops_pubmed_ids($stock) ],
		   );

  my $json_text = $json->encode($document);
  chomp($json_text);
  print ",\n" if ($needcomma++);
  print qq!$json_text\n!;

  # now handle phenotypes

  # reuse the sample document data structure
  # to avoid having to do a lot of cvterms fields over and over again
  foreach my $phenotype_assay (@phenotype_assays) {
    # is it a phenotype that we can use?
    my @protocol_types = map { $_->type } $phenotype_assay->protocols->all;

    if (grep { $_->id == $ir_assay_base_term->id ||
	       $ir_assay_base_term->has_child($_) } @protocol_types) {

      # yes we have an INSECTICIDE RESISTANCE BIOASSAY

      # cloning is safer and simpler (but more expensive) than re-using $document
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

	my $phenotype_stable_ish_id = $stable_id.".".$phenotype->id;
	# alter fields
	$doc->{id} = $phenotype_stable_ish_id;
	$doc->{url} = '/popbio/assay/?id='.$assay_stable_id; # this is closer to the phenotype than the sample page
	$doc->{label} = $phenotype->name;

	# NEW fields

	# figure out what kind of value
	my $value = $phenotype->value;

	if (defined $value && looks_like_number($value)) {
	  $doc->{phenotype_value_f} = $value;

	  my $value_unit = $phenotype->unit;
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

	  my $json_text = $json->encode($doc);
	  chomp($json_text);
	  print ",\n" if ($needcomma++);
	  print qq!$json_text\n!;

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
  foreach my $genotype (@genotypes) {
    # TO DO
  }

  last if ($limit && ++$done >= $limit);
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

# returns date of first assay with a date 
# DEPRECATED
sub stock_date {
  my $stock = shift;
  foreach my $assay ($stock->nd_experiments) {
    my $date = assay_date($assay);
    return $date if ($date); # already iso8601 from assay_date
  }
  return undef;
}


# assay_date($assay)
#
# returns single date string
# takes the FIRST start_date and end_date, or FIRST date (if multiple)
# currently doesn't complain if there are multiple dates of the same type (e.g. two start_dates)
# but I don't think there is anything like that in the database.
#
# start_date and end_date must both be present to return a range
# will return undef if can't return a range or single date
#
sub assay_date {
  my $assay = shift;
  my ($start_date, $end_date, $date);

  # loop through props finding values for start_date, end_date and date "keys" (first cvterm)
  foreach my $prop ($assay->multiprops) {
    my $key_term_id = ($prop->cvterms)[0]->id;
    given ($key_term_id) {
      when ($start_date_term_id) {
	$start_date //= $prop->value;
      }
      when ($end_date_term_id) {
	$end_date //= $prop->value;
      }
      when ($date_term_id) {
	$date //= $prop->value;
      }
    }
  }
  if (defined $start_date && defined $end_date) {
    if ($start_date eq $end_date) {
      return $start_date;
    } else {
      return "[$start_date TO $end_date]";
    }
  } elsif (defined $date) {
    return $date;
  }
  return undef;
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
