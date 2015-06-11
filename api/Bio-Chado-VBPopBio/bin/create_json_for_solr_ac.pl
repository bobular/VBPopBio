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

# stops "wide character in print" warnings
binmode(STDOUT, ":utf8");

#
# debug only
#
if ($project_stable_id) {
  my $project = $projects->find_by_stable_id($project_stable_id);
  $stocks = $project->stocks;
  $assays = $project->experiments;
}


# 'bioassay' MIRO:20000058
# because unfortunately we have used MIRO:20000100 (PCR amplification of specific alleles)
# to describe genotype assays totally unrelated to insecticide resistance
my $ir_assay_base_term = $schema->cvterms->find_by_accession({ term_source_ref => 'MIRO',
							       term_accession_number => '20000058' });

# insecticidal substance
my $insecticidal_substance = $schema->cvterms->find_by_accession({ term_source_ref => 'MIRO',
							       term_accession_number => '10000239' });

my $iso8601 = DateTime::Format::ISO8601->new;

print "{\n";

### PROJECTS ###
$done = 0;
my $study_design_type = $schema->types->study_design;
my $start_date_type = $schema->types->start_date;
my $date_type = $schema->types->date;


# I'm leaving this here for now just in case I need bits of code later
# For the popbio autocomplete SOLR code we only need data for samples and IR assays.

# while (my $project = $projects->next) {
  # my $stable_id = $project->stable_id;
  # my @design_terms = map { $_->cvterms->[1] } $project->multiprops($study_design_type);
  # my $document = { doc =>
		   # {
		    # label => $project->name,
		    # id => $stable_id,
		    # accession => $stable_id,
		    # # type => 'project', # doesn't seem to be in schema
		    # bundle => 'pop_project',
		    # bundle_name => 'Project',
		    # site=> 'Population Biology',
	            # url => '/popbio/project/?id='.$stable_id,
		    # entity_type => 'popbio',
		    # entity_id => $project->id,
		    # description => $project->description ? $project->description : '',
		    # date => iso8601_date($project->public_release_date),
		    # authors => [
				# map { $_->description } $project->contacts
			       # ],
		    # study_designs => [
				      # map { $_->name } @design_terms
				     # ],
		    # study_designs_cvterms => [
					      # map { flattened_parents($_) } @design_terms
					     # ],
		    # pubmed => [ map { "PMID:$_" } grep { $_ } map { $_->miniref } $project->publications ],
		   # }
		 # };
  # my $json_text = $json->encode($document);
  # chomp($json_text);
  # print qq!"add": $json_text,\n!;

  # last if ($limit && ++$done >= $limit);
# }


### SAMPLES ###
$done = 0;
while (my $stock = $stocks->next) {
  my $stable_id = $stock->stable_id;
  die "stock with db id ".$stock->id." does not have a stable id" unless ($stable_id);

  my @collection_protocol_types = map { $_->type } map { $_->protocols->all } $stock->field_collections;
  my $latlong = stock_latlong($stock);
  
  next if (!defined $latlong);
  my $stock_best_species = $stock->best_species();
  my $fc = $stock->field_collections->first;
  my @tmp;

  # We need several documents for each sample, one for every autocomplete entity (e.g. Taxon, Projects, pubmedid, paper titles)
  
  # first for taxons
  my @taxons;
  my $json_text;
  ($stock_best_species) ? (@taxons = flattened_parents($stock_best_species)) : (push @taxons, "Unknown");
	my $i = 0;
  foreach my $taxon (@taxons) {

	  my $documentTaxons = { doc =>
			   {
				id => $stable_id . "_taxon_" . $i,
				stable_id => $stable_id,
				type => 'Taxonomy',
				bundle => 'pop_sample',
				date => stock_date($stock),
				(defined $latlong ? ( geo_coords => $latlong ) : ()),
				($i==0) ? (
							textboost => 100,
							field => 'species'
						) : (
							textboost => 0,
							field => 'species_cvterms'
						) ,
				textsuggest => $taxon,
			   }
			 };

			 
	  $json_text = $json->encode($documentTaxons);
	  chomp($json_text);
	  print qq!"add": $json_text,\n!;
	  $i++;
}

  my $documentDescription = { doc =>
		   {
		    id => $stable_id . "_desc",
			stable_id => $stable_id,
		    type => 'Description',
			field => 'description',
		    bundle => 'pop_sample',
			(defined $latlong ? ( geo_coords => $latlong ) : ()),
		    date => stock_date($stock),
		    textsuggest => $stock->description || join(' ', ($stock_best_species ? $stock_best_species->name : ()), $stock->type->name, ($fc ? $fc->geolocation->summary : ())),
		   }
		 };  
  
  $json_text = $json->encode($documentDescription);
  chomp($json_text);
  print qq!"add": $json_text,\n!;
  
  my $documentTitle = { doc =>
		   {
		    id => $stable_id . "_title",
			stable_id => $stable_id,
		    type => 'Title',
			field => 'label',
		    bundle => 'pop_sample',
			(defined $latlong ? ( geo_coords => $latlong ) : ()),
		    date => stock_date($stock),
		    textsuggest => $stock->name,

		   }
		 };  
  
  $json_text = $json->encode($documentTitle);
  chomp($json_text);
  print qq!"add": $json_text,\n!;
  
    my $documentID = { doc =>
		   {
		    id => $stable_id . "_stable_id",
			stable_id => $stable_id,
		    type => 'stable_id',
			field => 'id',
		    bundle => 'pop_sample',
			(defined $latlong ? ( geo_coords => $latlong ) : ()),
		    date => stock_date($stock),
		    textsuggest => $stable_id,

		   }
		 };  
  
  $json_text = $json->encode($documentTitle);
  chomp($json_text);
  print qq!"add": $json_text,\n!; 
  
  # my $documentPubmed = { doc =>
		   # {
		    # id => $stable_id . "_pmid",
		    # bundle => 'pop_sample',
		    # type => 'Pubmed ID',
			# field => 'pubmed',
		    # has_geodata => (defined $latlong ? 'true' : 'false'),
		    # (defined $latlong ? ( geo_coords_fields($latlong) ) : ()),
		    # date => stock_date($stock),
			# textsuggest => [ map { "PMID:$_" } multiprops_pubmed_ids($stock) ],
		   # }
		 # };  
  
  # $json_text = $json->encode($documentPubmed);
  # chomp($json_text);
  # print qq!"add": $json_text,\n!;
  
  $i = 0;
  foreach my $project ($stock->projects) {
	  my $documentProjects = { doc =>
			   {
				id => $stable_id . "_proj_" . $i,
				stable_id => $stable_id,
				bundle => 'pop_sample',
				type => 'Projects',
				(defined $latlong ? ( geo_coords => $latlong ) : ()),
				date => stock_date($stock),
				textsuggest => quick_project_stable_id($project),
				field => 'projects',
				}
			 };  
	  
	  $json_text = $json->encode($documentProjects);
	  chomp($json_text);
	  print qq!"add": $json_text,\n!;  
	  $i++;
  }
  
  last if ($limit && ++$done >= $limit);
}


# ### ASSAYS ###
# $done = 0;
# while (my $assay = $assays->next) {
  # my $stable_id = $assay->stable_id;
  # die "assay with db id ".$assay->id." does not have a stable id" unless ($stable_id);

  # my @protocol_types = map { $_->type } $assay->protocols->all;
  # my $assay_type_name = $assay->type->name;
  # my ($latlong, $geoloc, $assay_best_species, @tmp);
  # if ($assay_type_name eq 'field collection') {
    # $geoloc = $assay->geolocation;
    # my $lat = $geoloc->latitude;
    # my $long = $geoloc->longitude;
    # $latlong = "$lat,$long" if (defined $lat && defined $long);
  # } elsif ($assay_type_name eq 'species identification method') {
    # $assay_type_name = 'species identification assay';
    # $assay_best_species = $assay->best_species;
  # }

  # my @assay_pubmed_ids = map { "PMID:$_" } multiprops_pubmed_ids($assay);

  # my $document = { doc =>
		   # {
		    # label => $assay->external_id,
		    # id => $stable_id,
		    # # type => 'sample', # doesn't seem to be in schema
		    # accession => $stable_id,
		    # bundle => 'pop_assay',
		    # bundle_name => 'Assay',
	  	    # site => 'Population Biology',
		    # url => '/popbio/assay/?id='.$stable_id,
		    # entity_type => 'popbio',
		    # entity_id => $assay->id,
		    # description => $assay->description || $assay->result_summary,

		    # assay_type => $assay_type_name,
		    # # not expanding this because it's a flat

		    # projects => [ map { quick_project_stable_id($_) } $assay->projects ],

		    # protocols => [ map { $_->name } @protocol_types ],
		    # protocols_cvterms => [ map { flattened_parents($_) } @protocol_types ],

		    # date => assay_date($assay),


		    # has_geodata => (defined $latlong ? 'true' : 'false'),
		    # (defined $latlong ? ( geo_coords_fields($latlong) ) : ()),

		    # ( $geoloc ? (
				 # geolocations => [ $geoloc->summary ],
				 # geolocations_cvterms => [ map { flattened_parents($_) } multiprops_cvterms($geoloc) ],
				# ) : () ),

		    # genotypes =>  [ map { ($_->description, $_->name) } (@tmp = $assay->genotypes) ],
		    # genotypes_cvterms => [ map { flattened_parents($_)  } map { ( $_->type, multiprops_cvterms($_) ) } @tmp ],

		    # phenotypes =>  [ map { $_->name } (@tmp = $assay->phenotypes) ],
		    # phenotypes_cvterms => [ map { flattened_parents($_)  } grep { defined $_ } map { ( $_->observable, $_->attr, $_->cvalue, multiprops_cvterms($_) ) } @tmp ],


		    # annotations => [ map { $_->as_string } $assay->multiprops ],
		    # annotations_cvterms => [ map { flattened_parents($_) } multiprops_cvterms($assay) ],

		    # ($assay_best_species ? (
					    # species => [ $assay_best_species->name ],
					    # species_cvterms => [ flattened_parents($assay_best_species) ],
					   # ) : ()),

		    # pubmed => \@assay_pubmed_ids,

		   # }
		 # };


  # my $json_text = $json->encode($document);
  # chomp($json_text);
  # print qq!"add": $json_text,\n!;


  # ### IR assay special case ###
  # if (grep { $_->id == $ir_assay_base_term->id ||
	       # $ir_assay_base_term->has_child($_) } @protocol_types) {

    # # warn "I found an IR assay for $stable_id ".join("\n", map { $_->name } @protocol_types)."\n\n";

    # my $sample = $assay->stocks->count == 1 ? $assay->stocks->first : undef;
    # if (defined $sample) {
      # my $fc = $sample->field_collections->first;
      # if (defined $fc) {
	# my $latlong;
	# my ($lat, $long) = ($fc->geolocation->latitude, $fc->geolocation->longitude);
	# $latlong = "$lat,$long" if (defined $lat && defined $long);

	# my @collection_protocol_types = map { $_->type } $fc->protocols->all;
	# my $sample_best_species = $sample->best_species;
	# my @insecticides = assay_insecticides($assay);

	# my $document =
	  # { doc =>
	    # {
	     # label => $assay->external_id,
	     # accession => $stable_id,
	     # site => 'Population Biology',
	     # bundle => 'pop_ir_assay',
	     # bundle_name => 'Insecticide resistance assay',
	     # id => $stable_id.".IR", # must be unique across whole of Solr

	     # url => '/popbio/assay/?id='.$stable_id,
	     # entity_type => 'popbio',
	     # entity_id => $assay->id,
	     # description => $assay->description || $assay->result_summary,

	     # date => assay_date($assay),

	     # collection_date => $fc ? assay_date($fc) : undef,

	     # has_geodata => (defined $latlong ? 'true' : 'false'),
	     # (defined $latlong ? ( geo_coords_fields($latlong) ) : ()),

	     # geolocations => [ $fc->geolocation->summary ],
	     # geolocations_cvterms => [ map { flattened_parents($_) } multiprops_cvterms($fc->geolocation) ],

	     # collection_protocols => [ map { $_->name } @collection_protocol_types ],
	     # collection_protocols_cvterms => [ map { flattened_parents($_) } @collection_protocol_types ],

	     # ($sample_best_species ? (
				      # species => [ $sample_best_species->name ],
				      # species_cvterms => [ flattened_parents($sample_best_species) ],
				     # ) : () ),

	     # protocols => [ map { $_->name } @protocol_types ],
	     # protocols_cvterms => [ map { flattened_parents($_) } @protocol_types ],

	     # phenotypes =>  [ map { $_->name } (@tmp = $assay->phenotypes) ],
	     # phenotypes_cvterms => [ map { flattened_parents($_)  } grep { defined $_ } map { ( $_->observable, $_->attr, $_->cvalue, multiprops_cvterms($_) ) } @tmp ],

	     # insecticides => [ map { $_->name } @insecticides ],
	     # insecticides_cvterms => [ map { flattened_parents($_) } @insecticides ],

	     # pubmed => \@assay_pubmed_ids,
	    # }
	  # };



	# my $json_text = $json->encode($document);
	# chomp($json_text);
	# print qq!"add": $json_text,\n!;
      # }
    # }
  # }


  # last if ($limit && ++$done >= $limit);
# }

# the commit is needed to resolve the trailing comma
print qq!\"commit\" : { } }\n!;

# returns just the 'proper' cvterms for all multiprops
# of the argument 
sub multiprops_cvterms {
  my $object = shift;
  return grep { $_->dbxref->as_string =~ /^\w+:\d+$/ } map { $_->cvterms } $object->multiprops;
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
sub stock_date {
  my $stock = shift;
  foreach my $assay ($stock->nd_experiments) {
    my $date = assay_date($assay);
    return $date if ($date); # already iso8601 from assay_date
  }
  return undef;
}


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

# converts poss truncated string date into ISO8601 Zulu time (hacked with an extra Z for now)
sub iso8601_date {
  my $string = shift;
  my $datetime = $iso8601->parse_datetime($string);
  if (defined $datetime) {
    return $datetime->datetime."Z";
  }
}

# returns an array of cvterms
# definitely want has child only (not IS also) because
# the insecticidal_substance term is used as a multiprop "key"
sub assay_insecticides {
  my $assay = shift;
  return grep { $insecticidal_substance->has_child($_) } map { $_->cvterms } $assay->multiprops;
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