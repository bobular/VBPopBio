#!/usr/bin/env perl
#                 -*- mode: cperl -*-
#
# usage: bin/create_json_for_solr.pl output-prefix
#
# will write files to output-prefix-01.json.gz output-prefix-02.json.gz AND output-prefix-ac-01.json.gz etc
#
# it will do both the main index and autocomplete
#
#
# writes an error log to output-prefix.log
#
# option:
#   --chunk-size          # how many docs per main output file chunk (autocomplete will have 5x this)
#   --project VBP0000123   # or comma-delimited list of VBPs - will only process these project(s)
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
use DateTime::EpiWeek;
use Geohash;
use Clone qw(clone);
use Tie::IxHash;
use Scalar::Util qw(looks_like_number);
use PDL;
use Math::Spline;
use List::MoreUtils;
use utf8::all;
use IO::Compress::Gzip;

my $dbname = $ENV{CHADO_DB_NAME};
my $dbuser = $ENV{USER};
my $dry_run;
my $wanted_project_ids;
my $inverted_IR_regexp = qr/^(LT|LC|fraction greater than \d+th percentile activity)/;
my $loggable_IR_regexp = qr/^(LT|LC)/;
my $chunk_size = 200000;

GetOptions("dbname=s"=>\$dbname,
	   "dbuser=s"=>\$dbuser,
	   "dry-run|dryrun"=>\$dry_run,
	   "projects=s"=>\$wanted_project_ids, # project(s) for debugging, can be comma-separated
	   "chunk_size|chunksize=i"=>\$chunk_size, # number of docs in each output chunk
	  );


my ($output_prefix) = @ARGV;
my $ac_chunk_size = $chunk_size * 20;

die "must provide output prefix commandline arg\n" unless ($output_prefix);

# configuration for autocomplete
my $ac_config =
  {
   pop_sample =>
   {
    species_cvterms =>              { type => "Taxonomy", cvterms => 1 },
    description =>                  { type => "Description" },
    label =>                        { type => "Title" },
    sample_id_s =>                  { type => "Sample ID" },
    pubmed =>                       { type => "PubMed", multi => 1 },
    projects =>                     { type => "Project", multi => 1 },
    project_titles_txt =>           { type => "Project title", multi => 1 },
    project_authors_txt =>          { type => "Author", multi => 1 },
    sample_type =>                  { type => "Sample type" },
    geolocations_cvterms =>         { type => "Geography", cvterms => 1 },
    collection_protocols_cvterms => { type => "Collection protocol", cvterms => 1 },
    protocols_cvterms =>            { type => "Protocol", cvterms => 1 },
    tags_cvterms =>                 { type => "Tag", cvterms => 1 },
    licenses_cvterms =>             { type => "License", cvterms => 1 },
    attractants_cvterms =>          { type => "Attractant", cvterms => 1 },
    sex_s =>                        { type => "Sex" },
   },
   pop_sample_phenotype => 
   {
    species_cvterms =>              { type => "Taxonomy", cvterms => 1 },
    description =>                  { type => "Description" },
    label =>                        { type => "Title" },
    assay_id_s =>                   { type => "Assay ID" },
    pubmed =>                       { type => "PubMed", multi => 1 },
    projects =>                     { type => "Project", multi => 1 },
    project_titles_txt =>           { type => "Project title", multi => 1 },
    project_authors_txt =>          { type => "Author", multi => 1 },
    sample_type =>                  { type => "Sample type" },
    geolocations_cvterms =>         { type => "Geography", cvterms => 1 },
    collection_protocols_cvterms => { type => "Collection protocol", cvterms => 1 },
    protocols_cvterms =>            { type => "Protocol", cvterms => 1 },
    tags_cvterms =>                 { type => "Tag", cvterms => 1 },
    licenses_cvterms =>             { type => "License", cvterms => 1 },
    sex_s =>                        { type => "Sex" },
    # IR view
    insecticide_cvterms =>          { type => "Insecticide", cvterms => 1 },
    # pathogen view
    infection_source_cvterms =>     { type => "Pathogen", cvterms => 1 },
    infection_status_s =>           { type => "Infection status" },
   },
   pop_sample_genotype =>
   {
    species_cvterms =>              { type => "Taxonomy", cvterms => 1 },
    description =>                  { type => "Description" },
    label =>                        { type => "Title" },
    assay_id_s =>                   { type => "Assay ID" },
    pubmed =>                       { type => "PubMed", multi => 1 },
    projects =>                     { type => "Project", multi => 1 },
    project_titles_txt =>           { type => "Project title", multi => 1 },
    project_authors_txt =>          { type => "Author", multi => 1 },
    sample_type =>                  { type => "Sample type" },
    geolocations_cvterms =>         { type => "Geography", cvterms => 1 },
    collection_protocols_cvterms => { type => "Collection protocol", cvterms => 1 },
    protocols_cvterms =>            { type => "Protocol", cvterms => 1 },
    tags_cvterms =>                 { type => "Tag", cvterms => 1 },
    licenses_cvterms =>             { type => "License", cvterms => 1 },
    sex_s =>                        { type => "Sex" },
    # genotype specific:
    genotype_name_s =>              { type => "Allele" },  # this could be tricky if we add microsats
    locus_name_s =>                 { type => "Locus" },
   }

  };


my $log_filename = "$output_prefix.log";
my $log_size = 0;

my ($document_counter, $ac_document_counter, $chunk_counter, $ac_chunk_counter) = (0, 0, 0, 0);
my ($chunk_fh, $ac_chunk_fh);

my $dsn = "dbi:Pg:dbname=$dbname";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $dbuser, undef, { AutoCommit => 1 });
# the next line is for extra speed - but check for identical results with/without
$schema->storage->_use_join_optimizer(0);
my $stocks = $schema->stocks;
my $projects = $schema->projects;

my $json = JSON->new->pretty; # useful for debugging
my $gh = Geohash->new();
my $done;
my ($needcomma, $ac_needcomma) = (0, 0);

#
# restrict to one or several projects
#
my %wanted_projects;
if (defined $wanted_project_ids) {
  # need to collect the raw database IDs for the $projects->search below
  my @project_db_ids;
  foreach my $vbp (split /\W+/, $wanted_project_ids) {
    my $project = $projects->find_by_stable_id($vbp);
    push @project_db_ids, $project->project_id;
    $wanted_projects{$vbp} = 1;
  }
  $stocks = $projects->search({ "me.project_id" => { in => \@project_db_ids }})->stocks;
}


# the following looks ripe for refactoring...

# 'bioassay' MIRO:20000058
# because unfortunately we have used MIRO:20000100 (PCR amplification of specific alleles)
# to describe genotype assays totally unrelated to insecticide resistance
my $ir_assay_base_term = $schema->cvterms->find_by_accession({ term_source_ref => 'MIRO',
							       term_accession_number => '20000058' }) || die;

# 'biochemical assay' MIRO:20000003 - also an allowable IR phenotype parent term
my $ir_biochem_assay_base_term = $schema->cvterms->find_by_accession({ term_source_ref => 'MIRO',
							       term_accession_number => '20000003' }) || die;

my $dose_response_test_term = $schema->cvterms->find_by_accession({ term_source_ref => 'MIRO',
								 term_accession_number => '20000076' }) || die;
# MIRO:00000003
my $metabolic_resistance_term = $schema->cvterms->find_by_accession({ term_source_ref => 'MIRO',
								 term_accession_number => '00000003' }) || die;

# insecticidal substance
my $insecticidal_substance = $schema->cvterms->find_by_accession({ term_source_ref => 'MIRO',
							       term_accession_number => '10000239' }) || die;

# quantitative qualifier
my $quantitative_qualifier = $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv',
							       term_accession_number => '0000702' }) || die;

my $concentration_term = $schema->cvterms->find_by_accession({ term_source_ref => 'PATO',
							       term_accession_number => '0000033' }) || die;

my $duration_term = $schema->cvterms->find_by_accession({ term_source_ref => 'EFO',
							       term_accession_number => '0000433' }) || die;

my $sample_size_term = $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv',
							       term_accession_number => '0000983' }) || die;

my $chromosomal_inversion_term = $schema->cvterms->find_by_accession({ term_source_ref => 'SO', 
                      term_accession_number => '1000030' }) || die;

my $inversion_term = $schema->cvterms->find_by_accession({ term_source_ref => 'SO',
                     term_accession_number => '1000036' }) || die;

my $genotype_term = $schema->cvterms->find_by_accession({ term_source_ref => 'SO',
                     term_accession_number => '0001027' }) || die;

my $karyotype_term = $schema->cvterms->find_by_accession({ term_source_ref => 'EFO',
                     term_accession_number => '0004426' }) || die;

my $count_unit_term = $schema->cvterms->find_by_accession({ term_source_ref => 'UO',
                     term_accession_number => '0000189' }) || die;

my $percent_term = $schema->cvterms->find_by_accession({ term_source_ref => 'UO',
							 term_accession_number => '0000187' }) || die;

my $simple_sequence_length_polymorphism_term = $schema->cvterms->find_by_accession({ term_source_ref => 'SO',
										     term_accession_number => '0000207' }) || die;

my $microsatellite_term = $schema->cvterms->find_by_accession({ term_source_ref => 'SO',
								term_accession_number => '0000289' }) || die;

my $length_term = $schema->cvterms->find_by_accession({ term_source_ref => 'PATO',
							term_accession_number => '0000122' }) || die;

my $mutated_protein_term = $schema->cvterms->find_by_accession({ term_source_ref => 'IDOMAL',
								 term_accession_number => '50000004' }) || die;

my $wild_type_allele_term = $schema->cvterms->find_by_accession({ term_source_ref => 'IRO',
								 term_accession_number => '0000001' }) || die;

my $variant_frequency_term = $schema->cvterms->find_by_accession({ term_source_ref => 'SO',
								   term_accession_number => '0001763' }) || die;

my $reference_genome_term = $schema->cvterms->find_by_accession({ term_source_ref => 'SO',
								   term_accession_number => '0001505' }) || die;

my $blood_meal_term = $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv',
							    term_accession_number => '0001003' }) || die;

my $blood_meal_source_term = $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv',
								   term_accession_number => '0001004' }) || die;

my $arthropod_infection_status_term = $schema->cvterms->find_by_accession({ term_source_ref => 'VSMO',
									    term_accession_number => '0000009' }) || die;

my $arthropod_host_blood_index_term = $schema->cvterms->find_by_accession({ term_source_ref => 'VSMO',
									    term_accession_number => '0000132' }) || die;

my $parent_term_of_present_absent = $schema->cvterms->find_by_accession({ term_source_ref => 'PATO',
									  term_accession_number => '0000070' }) || die;

my $infection_prevalence_term = $schema->cvterms->find_by_accession({ term_source_ref => 'IDO',
								      term_accession_number => '0000486' }) || die;

my $sequence_variant_position = $schema->cvterms->find_by_accession({ term_source_ref => 'IRO',
								      term_accession_number => '0000123' }) || die;

# CC BY
my $default_license = $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv',
							    term_accession_number => '0001107' }) || die;

my $sex_heading_term = $schema->types->sex;
my $developmental_stage_term = $schema->types->developmental_stage;
my $attractant_term = $schema->types->attractant;
my $sar_term = $schema->types->species_assay_result;

my $iso8601 = DateTime::Format::ISO8601->new;

### PROJECTS ###
$done = 0;
my $study_design_type = $schema->types->study_design;
my $start_date_type = $schema->types->start_date;
my $end_date_type = $schema->types->end_date;
my $date_type = $schema->types->date;
my $usage_license_term = $schema->types->usage_license;

# remember some project info for sample docs
my %project2title;
my %project2authors;
my %project2pubmed; # PMIDs
my %project2citations; # PMID or DOI or URL
my %project2tags; # project id => [ tag_cvterm_objects ]
my %project2licenses; # project id => [ tag_cvterm_objects ]

while (my $project = $projects->next) {
  my $stable_id = $project->stable_id;
  my @design_terms = map { $_->cvterms->[1] } $project->multiprops($study_design_type);
  my @publications = $project->publications;
  my @tag_terms = $project->tags;
  my @license_terms = grep { $usage_license_term->has_child($_) } @tag_terms;
  @tag_terms = grep { ! $usage_license_term->has_child($_) } @tag_terms;

  # default license
  push @license_terms, $default_license unless (@license_terms);

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
		    date => iso8601_date($project->public_release_date // $project->submission_date),
		    authors => [
				(map { sanitise_contact($_->description) } $project->contacts),
				(map { $_->authors } @publications)
			       ],
		    study_designs => [
				      map { $_->name } @design_terms
				     ],
		    study_designs_cvterms => [
					      map { flattened_parents($_) } @design_terms
					     ],
		    pubmed => [ map { "PMID:$_" } grep { $_ } map { $_->pubmed_id } @publications ],
		    publications_status => [ map { $_->status->name } @publications ],
		    publications_status_cvterms => [ map { flattened_parents($_->status) } @publications ],
		    exp_citations_ss => [ map { $_->pubmed_id ? "PMID:".$_->pubmed_id : (),
						$_->doi ? "DOI:".$_->doi : (),
						$_->url || () } @publications ],

		    tags_ss => [ map { $_->name } @tag_terms ],
		    tags_cvterms => [ map { flattened_parents($_) } @tag_terms ],

		    licenses_ss => [ map { $_->name } @license_terms ],
		    licenses_cvterms => [ map { flattened_parents($_) } @license_terms ],
		    );

  print_document($output_prefix, $document, $ac_config) if (!defined $wanted_project_ids || $wanted_projects{$stable_id});

  $project2title{$stable_id} = $document->{label};
  $project2authors{$stable_id} = $document->{authors};
  $project2pubmed{$stable_id} = $document->{pubmed};
  $project2citations{$stable_id} = $document->{exp_citations_ss};
  $project2tags{$stable_id} = \@tag_terms;
  $project2licenses{$stable_id} = \@license_terms;
}

#
# store phenotype values for later normalisation
#

my %phenotype_signature2values; # measurement_type/assay/insecticide/concentration/c_units/duration/d_units/species => [ vals, ... ]
my %phenotype_id2value; # phenotype_stable_ish_id => un-normalised value
my %phenotype_id2signature; # phenotype_stable_ish_id => signature

### SAMPLES ###
my $done_samples = 0;
my $done_ir_phenotypes = 0;
my $done_genotypes = 0;
my ($done_bm_phenotypes, $done_infection_phenotypes) = (0, 0);

while (my $stock = $stocks->next) {
  my $stable_id = $stock->stable_id;

  die "stock with db id ".$stock->id." does not have a stable id" unless ($stable_id);

  my @collection_protocol_types = map { $_->type } map { $_->protocols->all } $stock->field_collections;
  my $latlong = stock_latlong($stock); # only returns coords if one site
  my $stock_best_species = $stock->best_species();

  my @field_collections = $stock->field_collections;
  my $fc = $field_collections[0];

  my @phenotype_assays = $stock->phenotype_assays;
  my @phenotypes = map { $_->phenotypes->all } @phenotype_assays;

  my @genotype_assays = $stock->genotype_assays;
  my @genotypes = map { $_->genotypes->all } @genotype_assays;

  my @projects = map { quick_project_stable_id($_) } $stock->projects;

  my @species_assays = $stock->species_identification_assays;
  my @other_protocols = map { $_->protocols } @phenotype_assays, @genotype_assays, @species_assays;
  my @other_protocols_types = map { $_->type } @other_protocols;

  my @reference_genome_props = grep { ($_->cvterms)[0]->id == $reference_genome_term->id } map { $_->multiprops } @genotype_assays;

  my %assay_date_fields;
  %assay_date_fields = assay_date_fields($fc) if defined $fc;

  my ($sample_size) = map { $_->value } $stock->multiprops($sample_size_term);
  if (defined $sample_size) {
    if (!looks_like_number($sample_size)) {
      log_message("$stable_id (@projects) sample has non-numeric sample_size '$sample_size'");
      undef $sample_size;
    } elsif ($sample_size =~ /\d+\.\d+/) {
      log_message("$stable_id (@projects) sample has non-integer sample_size '$sample_size' - using int(x)");
      $sample_size = int($sample_size);
    }
  }

  my $sample_type = $stock->type->name;

  my $has_abundance_data = defined $sample_size &&
    $assay_date_fields{collection_duration_days_i} &&
      $sample_type eq 'pool';

  my ($sex_value_term) = map { ($_->cvterms)[1] } $stock->multiprops($sex_heading_term);
  my @dev_stage_terms = map { ($_->cvterms)[1] } $stock->multiprops($developmental_stage_term);
  my @attractant_terms = map { ($_->cvterms)[1] } map { $_->multiprops($attractant_term) } @field_collections;

  my $document = ohr(
		    label => $stock->name,
		    id => $stable_id,
		    # type => 'sample', # doesn't seem to be in schema
		    accession => $stable_id,
		    sample_id_s => $stable_id,
		    bundle => 'pop_sample',
		    bundle_name => 'Sample',
	  	    site => 'Population Biology',
		    url => '/popbio/sample/?id='.$stable_id,
		    entity_type => 'popbio',
		    entity_id => $stock->id,
		    description => $stock->description || join(' ', ($stock_best_species ? $stock_best_species->name : ()), $stock->type->name, ($fc ? $fc->geolocation->summary : ())),

		    sample_type => $sample_type,
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

		    projects => [ @projects ],

		    # used to be plain 'date' from any assay
		    # now it's collection_date if there's an unambiguous collection
		    (defined $fc ? ( collection_assay_id_s => $fc->stable_id ) : () ),

		    %assay_date_fields,

		    pubmed => [ (map { "PMID:$_" } multiprops_pubmed_ids($stock)),
				(map { @{$project2pubmed{$_}} } @projects)
			      ],

		    exp_citations_ss => [ (map { "PMID:$_" } multiprops_pubmed_ids($stock)),
				(map { @{$project2citations{$_}} } @projects)
			      ],

		    tags_ss => [ map { $_->name } map { @{$project2tags{$_}} } @projects ],
		    tags_cvterms => [ map { flattened_parents($_) } map { @{$project2tags{$_}} } @projects ],

		    licenses_ss => [ map { $_->name } map { @{$project2licenses{$_}} } @projects ],
		    licenses_cvterms => [ map { flattened_parents($_) } map { @{$project2licenses{$_}} } @projects ],

		    sample_karyotype_fields(@genotypes),

		    project_titles_txt => [ map { $project2title{$_} } @projects ],
		    project_authors_txt => [ map { @{$project2authors{$_}} } @projects ],

		    protocols => [ List::MoreUtils::uniq(map { $_->name } @other_protocols_types) ],
		    protocols_cvterms => [ List::MoreUtils::uniq(map { flattened_parents($_) } @other_protocols_types) ],

		    (@reference_genome_props == 1 ? ( reference_genome_s => $reference_genome_props[0]->value ) : () ),

		    (defined $sample_size ? (sample_size_i => $sample_size) : ()),

		     has_abundance_data_b => $has_abundance_data ? 1 : 0,

		     (defined $sex_value_term ? ( sex_s => $sex_value_term->name,
						  sex_cvterms => [ flattened_parents($sex_value_term) ] ) : ()),

		     (@dev_stage_terms>0 ? ( dev_stages_ss => [ map { $_->name } @dev_stage_terms ],
					     dev_stages_cvterms => [ map { flattened_parents($_) } @dev_stage_terms ] ) : ()),

		     attractants_ss => [ map { $_->name } @attractant_terms ],
		     attractants_cvterms => [ map { flattened_parents($_) } @attractant_terms ],

		     );

  #
  # these are needed if you have legend modes in the map for these fields
  #
  fallback_value($document->{collection_protocols}, 'no data');
  fallback_value($document->{protocols}, 'no data');
  fallback_value($document->{collection_protocols_cvterms}, 'no data');
  fallback_value($document->{protocols_cvterms}, 'no data');
  fallback_value($document->{attractants_ss}, 'no data');
  fallback_value($document->{attractants_cvterms}, 'no data');

  # split the species for zero abundance data
  # but only where there's one assay and many results VB-6319
  # but TO DO - write zero samples to a separate Solr output file
  if ($has_abundance_data && $sample_size == 0 && @species_assays==1) {
    my $doc_id = $document->{id};
    my $s=1;

    # take each species identification assay, and result from each one separately
    foreach my $species_assay (@species_assays) {
      foreach my $sar_multiprop ($species_assay->multiprops($sar_term)) {
	my $species = $sar_multiprop->cvterms->[-1]; # second/last term in chain

	$document->{id} = $doc_id.'.s'.$s++;
	if (defined $species) {
	  $document->{description} = "Confirmed absence of ".$species->name;
	  $document->{species} = [ $species->name ];
	  $document->{species_cvterms} = [ flattened_parents($species) ];
	} else {
	  $document->{description} = "Confirmed absence of unknown species";
	  $document->{species} = [ 'Unknown' ];
	  $document->{species_cvterms} = [ ];
	}

	# print the split zero abundance sample
	print_document($output_prefix, $document, $ac_config);
      }
    }
  } else {
    # print the sample as normal
    print_document($output_prefix, $document, $ac_config);
  }

  # now handle phenotypes

  # reuse the sample document data structure
  # to avoid having to do a lot of cvterms fields over and over again
  foreach my $phenotype_assay (@phenotype_assays) {
    my $assay_stable_id = $phenotype_assay->stable_id;


    my ($insecticide, $concentration, $concentration_unit, $duration, $duration_unit, $assay_sample_size, $errors) =
      assay_insecticides_concentrations_units_and_more($phenotype_assay);

    # is it a phenotype that we can use?
    my @protocol_types = map { $_->type } $phenotype_assay->protocols->all;

    if (grep { $_->id == $ir_assay_base_term->id ||   # should we audit the use of the base term and see if this can be made more strict
	       $ir_assay_base_term->has_child($_) ||
	       $ir_biochem_assay_base_term->has_child($_)  # don't allow the base term to be used for biochem assays
	     } @protocol_types) {

      # yes we have an INSECTICIDE RESISTANCE BIOASSAY or BIOCHEMICAL ASSAY

      # cloning is safer and simpler (but more expensive) than re-using $document
      # $document is the sample document
      my $doc = clone($document);

      # always change these fields
      $doc->{bundle} = 'pop_sample_phenotype';
      $doc->{bundle_name} = 'Sample phenotype';

      $doc->{url} = '/popbio/assay/?id='.$assay_stable_id; # this is closer to the phenotype than the sample page
      $doc->{accession} = $assay_stable_id;
      $doc->{assay_id_s} = $assay_stable_id;
      $doc->{sample_name_s} = $document->{label};

      delete $doc->{phenotypes};
      delete $doc->{phenotypes_cvterms};

      # NEW fields
      $doc->{phenotype_type_s} = "insecticide resistance";
      $doc->{protocols} = [ List::MoreUtils::uniq(map { $_->name } @protocol_types) ];
      $doc->{protocols_cvterms} = [ List::MoreUtils::uniq(map { flattened_parents($_) } @protocol_types) ];

      fallback_value($doc->{protocols}, 'no data');
      fallback_value($doc->{protocols_cvterms}, 'no data');

      foreach my $phenotype ($phenotype_assay->phenotypes) {
      	
      	#print "\t\t\tphenotype... @andy @done: remove later after  @remove\n";

		my $phenotype_stable_ish_id = $assay_stable_id.".".$phenotype->id;
		# alter fields
		$doc->{id} = $phenotype_stable_ish_id;
		$doc->{label} = $phenotype->name;
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
		    log_message("$assay_stable_id (@projects) has no value type for phenotype ".$phenotype->name." - skipping");
		    next;
		  }

		  # to do: insecticide + concentrations + duration
		  # die "to do...";

		  if ($errors) {
		    log_message("$assay_stable_id (@projects) phenotype ".$phenotype->name." had fatal errors: $errors - skipping");
		    next;
		  }

		  if (defined $insecticide) {
		    $doc->{insecticide_s} = $insecticide->name;
		    $doc->{insecticide_cvterms} = [ flattened_parents($insecticide) ];
		  } elsif ($phenotype->observable->id == $metabolic_resistance_term->id) {
		    $doc->{insecticide_s} = 'N/A (biochemical assay)';
		    $doc->{insecticide_cvterms} = [ $doc->{insecticide_s} ];
		  }
		  if (defined $doc->{insecticide_s}) {
		    if (defined $concentration && looks_like_number($concentration) && defined $concentration_unit) {
		      $doc->{concentration_f} = $concentration;
		      $doc->{concentration_unit_s} = $concentration_unit->name;
		      $doc->{concentration_unit_cvterms} = [ flattened_parents($concentration_unit) ];
		    } elsif (not grep { $_->id == $dose_response_test_term->id ||
					  $dose_response_test_term->has_child($_) ||
					  $ir_biochem_assay_base_term->has_child($_)
					} @protocol_types) {
		      # this warning only for non-DR and non-biochem tests
		      log_message("$assay_stable_id (@projects) has no/incomplete/corrupted concentration data for phenotype ".$phenotype->name." - keeping");
		    }

		  } else {
		    log_message("$assay_stable_id (@projects) - no insecticide for phenotype ".$phenotype->name." - skipping");
		    next;
		  }

		  if (defined $duration && defined $duration_unit) {
		    $doc->{duration_f} = $duration;
		    $doc->{duration_unit_s} = $duration_unit->name;
		    $doc->{duration_unit_cvterms} = [ flattened_parents($duration_unit) ];
		  } else {
		    # warn "no/incomplete duration data for $assay_stable_id\n";
		  }

		  if (defined $assay_sample_size) {
		    $doc->{sample_size_i} = $assay_sample_size;
		  }

		  # phenotype_cvterms (singular)
		  $doc->{phenotype_cvterms} = [ map { flattened_parents($_)  } grep { defined $_ } ( $phenotype->observable, $phenotype->attr, $phenotype->cvalue, multiprops_cvterms($phenotype) ) ];

		  print_document($output_prefix, $doc, $ac_config);

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
    } else {
      # other phenotype subtypes dealt with here
      foreach my $phenotype ($phenotype_assay->phenotypes) {
	my ($observable, $attribute, $cvalue) = ($phenotype->observable, $phenotype->attr, $phenotype->cvalue);

	# blood meal
	if (defined $observable && ($observable->id == $blood_meal_term->id || $observable->id == $blood_meal_source_term->id) &&
	    defined $attribute && $blood_meal_source_term->has_child($attribute) &&
	    defined $cvalue && $parent_term_of_present_absent->has_child($cvalue)) {
	  my $doc = clone($document);

	  # always change these fields
	  my $phenotype_stable_ish_id = $assay_stable_id.".".$phenotype->id;
	  $doc->{id} = $phenotype_stable_ish_id;
	  $doc->{bundle} = 'pop_sample_phenotype';
	  $doc->{bundle_name} = 'Sample phenotype';
	  $doc->{label} = $phenotype->name;
	  $doc->{url} = '/popbio/assay/?id='.$assay_stable_id; # this is closer to the phenotype than the sample page
	  $doc->{assay_id_s} = $assay_stable_id;
	  $doc->{sample_name_s} = $document->{label};

	  delete $doc->{phenotypes};
	  delete $doc->{phenotypes_cvterms};

	  # NEW fields
	  $doc->{phenotype_type_s} = "blood meal identification";
	  $doc->{protocols} = [ List::MoreUtils::uniq(map { $_->name } @protocol_types) ];
	  $doc->{protocols_cvterms} = [ List::MoreUtils::uniq(map { flattened_parents($_) } @protocol_types) ];
	  fallback_value($doc->{protocols}, 'no data');
	  fallback_value($doc->{protocols_cvterms}, 'no data');

	  $doc->{blood_meal_source_s} = $attribute->name;
	  $doc->{blood_meal_source_cvterms} = [ flattened_parents($attribute) ];
	  $doc->{blood_meal_status_s} = $cvalue->name;

	  if (defined $assay_sample_size) {
	    $doc->{sample_size_i} = $assay_sample_size;
	  }

	  # now add a fractional index if available
	  my ($index_prop) = $phenotype->multiprops($arthropod_host_blood_index_term);
	  if (defined $index_prop) {
	    # check the value is a percentage
	    my ($ahbi, $unit_term) = $index_prop->cvterms;
	    if (defined $unit_term && $unit_term->dbxref->db->name eq 'UO') {
	      $doc->{phenotype_value_f} = $index_prop->value;
	      $doc->{phenotype_value_type_s} = 'host blood index';
	      $doc->{phenotype_value_unit_s} = $unit_term->name;
	      $doc->{phenotype_value_unit_cvterms} =  [ flattened_parents($unit_term) ];
	    } else {
	      log_message("$assay_stable_id (@projects) - unitless blood meal index value for phenotype ".$phenotype->name." - skipping");
	      next;
	    }
	  }

	  print_document($output_prefix, $doc); # NO autocomplete ATM

	  ### infection phenotype ###
	} elsif (defined $observable && $observable->id == $arthropod_infection_status_term->id &&
		 defined $attribute && # no further tests here but expecting a species term
		 defined $cvalue && $parent_term_of_present_absent->has_child($cvalue)) {
	  my $doc = clone($document);

	  # always change these fields
	  my $phenotype_stable_ish_id = $assay_stable_id.".".$phenotype->id;
	  $doc->{id} = $phenotype_stable_ish_id;
	  $doc->{bundle} = 'pop_sample_phenotype';
	  $doc->{bundle_name} = 'Sample phenotype';
	  $doc->{label} = $phenotype->name;
	  $doc->{url} = '/popbio/assay/?id='.$assay_stable_id; # this is closer to the phenotype than the sample page
	  $doc->{assay_id_s} = $assay_stable_id;
	  $doc->{sample_name_s} = $document->{label};

	  delete $doc->{phenotypes};
	  delete $doc->{phenotypes_cvterms};

	  # NEW fields
	  $doc->{phenotype_type_s} = "infection status";
	  $doc->{protocols} = [ List::MoreUtils::uniq(map { $_->name } @protocol_types) ];
	  $doc->{protocols_cvterms} = [ List::MoreUtils::uniq(map { flattened_parents($_) } @protocol_types) ];
	  fallback_value($doc->{protocols}, 'no data');
	  fallback_value($doc->{protocols_cvterms}, 'no data');

	  $doc->{infection_source_s} = $attribute->name;
	  $doc->{infection_source_cvterms} = [ flattened_parents($attribute) ];
	  $doc->{infection_status_s} = $cvalue->name;

	  if (defined $assay_sample_size) {
	    $doc->{sample_size_i} = $assay_sample_size;
	  }

	  # now add a fractional index if available
	  my ($index_prop) = $phenotype->multiprops($infection_prevalence_term);
	  if (defined $index_prop) {
	    # check the value is a percentage
	    my ($ahbi, $unit_term) = $index_prop->cvterms;
	    if (defined $unit_term && $unit_term->dbxref->db->name eq 'UO') {
	      $doc->{phenotype_value_f} = $index_prop->value;
	      $doc->{phenotype_value_type_s} = 'infection prevalence';
	      $doc->{phenotype_value_unit_s} = $unit_term->name;
	      $doc->{phenotype_value_type_cvterms} = [ flattened_parents($unit_term) ];
	    } else {
	      log_message("$assay_stable_id (@projects) - unitless infection prevalence value for phenotype ".$phenotype->name." - skipping");
	      next;
	    }
	  }

          print_document($output_prefix, $doc, $ac_config);

	} else {
	  log_message("$assay_stable_id (@projects) has unexpected phenotype ".$phenotype->name." - skipped");
	}
      }
    }
  }

  # same for genotypes
  foreach my $genotype_assay (@genotype_assays) {
    my $assay_stable_id = $genotype_assay->stable_id;
    my @protocol_types = map { $_->type } $genotype_assay->protocols->all;

    my ($sample_size_prop) = $genotype_assay->multiprops($sample_size_term);
    my $assay_sample_size = defined $sample_size_prop ? $sample_size_prop->value : undef;

    foreach my $genotype ($genotype_assay->genotypes) {
      my ($genotype_name, $genotype_value, $genotype_subtype, $genotype_unit); # these vars are "undefined" to start with
      my $genotype_type = $genotype->type; # cvterm/ontology term object
      my $locus_term;

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
      } elsif ($mutated_protein_term->has_child($genotype_type) || $wild_type_allele_term->has_child($genotype_type)) {
	# these are ontology-defined mutant allele counts/frequencies
	# they are probably not to be confused with SNP genotype data from Ensembl when it comes to Solr...
	$genotype_name = $genotype_type->name;
	foreach my $prop ($genotype->multiprops) {
          my @prop_terms = $prop->cvterms;
          $genotype_value = $prop->value if ($prop_terms[0]->id == $count_unit_term->id ||
					     $prop_terms[0]->id == $variant_frequency_term->id);
	  $genotype_unit = $prop_terms[-1];
	}

	unless (defined $genotype_unit) {
	  log_message("$assay_stable_id (@projects) mutated protein genotype ".$genotype->name." has no units - skipping");
	  next;
	}

	$genotype_subtype = 'mutated protein';

	# determine which locus the allele is for
	# preload parent relationships
	$genotype_type->recursive_parents;
	my $genotype_parents = $genotype_type->direct_parents;
	while (my $term = $genotype_parents->next) {
	  if ($sequence_variant_position->has_child($term)) {
	    $locus_term = $term;
	  }
	}
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
	$doc->{sample_name_s} = $document->{label};

	delete $doc->{genotypes};
	delete $doc->{genotypes_cvterms};

	# NEW fields
	$doc->{genotype_type_s}   = $genotype_subtype;
	$doc->{protocols}         = [ List::MoreUtils::uniq(map { $_->name } @protocol_types) ];
	$doc->{protocols_cvterms} = [ List::MoreUtils::uniq(map { flattened_parents($_) } @protocol_types) ];

	fallback_value($doc->{protocols}, 'no data');
	fallback_value($doc->{protocols_cvterms}, 'no data');

	my $genotype_stable_ish_id = $stable_id.".".$genotype->id;
	# alter fields
	$doc->{id} = $genotype_stable_ish_id;
	$doc->{url} = '/popbio/assay/?id='.$assay_stable_id; # this is closer to the phenotype than the sample page
	$doc->{label} = $genotype->name;
	$doc->{accession} = $assay_stable_id;
	$doc->{assay_id_s} = $assay_stable_id;
	$doc->{description} = "$genotype_subtype genotype '".$genotype->description."' for $stable_id";

	$doc->{genotype_cvterms} = [ map { flattened_parents($_) } grep { defined $_ } ( $genotype->type, multiprops_cvterms($genotype) ) ];

	$doc->{genotype_name_s} = $genotype_name;

	if (defined $assay_sample_size) {
	  $doc->{sample_size_i} = $assay_sample_size;
	}


	my $ac = undef;
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
	    if (defined $locus_term) {
	      $doc->{locus_name_s} = $locus_term->name;
	      $doc->{locus_name_cvterms} = [ flattened_parents($locus_term) ];
	    }
	    $ac = $ac_config; # autocomplete ON for this subtype
	  }
	}

	print_document($output_prefix, $doc, $ac);
      }
    }
  }
}


#
# create a set of normaliser functions for each signature
#
my %phenotype_signature2normaliser;
foreach my $phenotype_signature (keys %phenotype_signature2values) {
  my $values = pdl(@{$phenotype_signature2values{$phenotype_signature}});

  # when inverted == 1, low values mean the insecticide is working
  my $inverted = ($phenotype_signature =~ $inverted_IR_regexp) ? 1 : 0;
  my $loggable = ($phenotype_signature =~ $loggable_IR_regexp) ? 1 : 0;

  my $who_spline;
  if ($phenotype_signature eq 'mortality rate/percent') {
    $who_spline = Math::Spline->new([0, 90, 98, 100],[0, 0.2, 0.8, 1]);
  }

  # log transform all values if required.
  $values = $values->log if ($loggable);

  my ($min, $max) = ($values->pct(0.02), $values->pct(0.98));
  my $range = $max - $min;

  if ($range) {
    $phenotype_signature2normaliser{$phenotype_signature} =
      sub {
	my $val = shift;
	if ($who_spline) {
	  # WHO spline transform
	  $val = $who_spline->evaluate($val);
	  # and hardcoded handling of out-of-range values
	  $val = 0 if ($val<0);
	  $val = 1 if ($val>1);
	} else {
	  # log transform
	  $val = log($val) if ($loggable);

	  # squash outliers
	  $val = $min if ($val<$min);
	  $val = $max if ($val>$max);
	  # now rescale
	  $val -= $min;
	  $val /= $range;
	  $val = 1-$val if ($inverted);
	}
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

    my $atomic_update_doc = ohr(
				id => $phenotype_stable_ish_id,
				phenotype_rescaled_value_f => { set => $rescaled },
				phenotype_rescaling_signature_s => { set => $phenotype_signature },
				phenotype_rescaling_count_i => { set => $n }
			       );
    print_document($output_prefix, $atomic_update_doc);
  }
}


#
# close the final chunks of output if necessary
#
if (defined $chunk_fh) {
  print $chunk_fh "]\n";
  close($chunk_fh);
}

if (defined $ac_chunk_fh) {
  print $ac_chunk_fh "]\n";
  close($ac_chunk_fh);
}

if ($log_size) {
  warn "$log_size errors or warnings reported in $log_filename\n";
}

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

# returns
# 1. collection_date => always an iso8601 date for the date or start_date
# 2. collection_date_range => a multi-valued DateRangeField with the Chado-resolution dates, or start-end date ranges
# 3. collection_season => One or more DateRangeField values in the year 1600 (an arbitrary leap year) used for seasonal search
# 4. collection_duration_days_i => number of days of collection effort
#
# by Chado-resolution we mean "2010-10" will refer automatically to a range including the entire month of October 2010
#
sub assay_date_fields {
  my $assay = shift;

  my $collection_duration_days = $assay->duration_in_days();
  my %result = (
		collection_date_range => [],
		collection_season => [],
	       );
  $result{collection_duration_days_i} = $collection_duration_days if defined $collection_duration_days;

  my @dates = $assay->multiprops($date_type);
  my @start_dates = $assay->multiprops($start_date_type);
  my @end_dates = $assay->multiprops($end_date_type);

  # first deal with the single date for Solr back-compatibility
  # use the first date or start_date
  my $single_date_from_chado;
  if ($dates[0]) {
    $single_date_from_chado = $dates[0]->value;
  } elsif ($start_dates[0]) {
    $single_date_from_chado = $start_dates[0]->value;
  }

  # fixed granularity, single-valued date fields for timeline plot zooming
  # we currently consider the START DATE ONLY - but subject to change...
  if ($single_date_from_chado) {
    $result{collection_date} = iso8601_date($single_date_from_chado);

    $result{collection_year_s} = substr($single_date_from_chado, 0, 4);
    $result{collection_date_resolution_s} = 'year';
    if (length($single_date_from_chado) >= 7) {
      $result{collection_month_s} = substr($single_date_from_chado, 0, 7);
      $result{collection_date_resolution_s} = 'month';
      if (length($single_date_from_chado) >= 10) {
	$result{collection_epiweek_s} = epiweek($single_date_from_chado);
	$result{collection_day_s} = $single_date_from_chado;
	$result{collection_date_resolution_s} = 'day';
      }
    }
  }

  # now deal with the potentially multi-valued dates and date ranges
  foreach my $date (map { $_->value } @dates) {
    push @{$result{collection_date_range}}, $date;
    push @{$result{collection_season}}, season($date);
  }

  unless (@start_dates == @end_dates) {
    log_message($assay->stable_id." has unequal number of start and end dates - records will have no date fields");
    return ();
  }
  for (my $i=0; $i<@start_dates; $i++) {
    my $start_date = $start_dates[$i]->value;
    my $end_date = $end_dates[$i]->value;

    my ($start_dt, $end_dt) = ($iso8601->parse_datetime($start_date), $iso8601->parse_datetime($end_date));
    if (DateTime->compare($start_dt, $end_dt) > 0) {
      ($start_date, $end_date) = ($end_date, $start_date);
    }

    if ($start_date eq $end_date) {
      push @{$result{collection_date_range}}, $start_date;
      push @{$result{collection_season}}, season($start_date);
    } else {
      push @{$result{collection_date_range}}, "[$start_date TO $end_date]";
      push @{$result{collection_season}}, season($start_date, $end_date);
    }
  }

  return %result;
}

#
sub season {
  my ($start_date, $end_date) = @_;
  if (!defined $end_date) {
    # a single date or low-resolution date (e.g. 2014) will be returned as-is
    # and converted by Solr into a date range as appropriate
    $start_date =~ s/^\d{4}/1600/;
    return $start_date;
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
      return ( "[$start_date TO $end_date]" );
    } else {
      # range spans new year, so return two ranges
      return ( "[$start_date TO 1600-12-31]",
	       "[1600-01-01 TO $end_date]" );
    }
  }
}

#
# calculate_duration_days
#
# uses the Solr-friendly date_range string to figure out the duration
#
# returns null if date range is not provided in day-resolution
#
# DOES NOT HANDLE HOUR-RESOLUTION DATA that might be in other Chado props
#
# The range [2010-03-10 TO 2010-03-11] has a duration of 2 days
# a single date has a duration of 1 day
#
sub calculate_duration_days {
  my ($date_range) = @_;
  if ($date_range =~ /\[(\d{4}-\d{2}-\d{2})\s+TO\s+(\d{4}-\d{2}-\d{2})\]/) {
    my ($start_date, $end_date) = ($1, $2);
    my ($start_dt, $end_dt) = ($iso8601->parse_datetime($start_date), $iso8601->parse_datetime($end_date));
    my $duration = $end_dt - $start_dt;
    return $duration->in_units('days') + 1;

  } elsif ($date_range =~ /^\d{4}-\d{2}-\d{2}$/) {
    # single date to day resolution
    return 1;
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

sub epiweek {
  my $string = shift;
  my $datetime = $iso8601->parse_datetime($string);
  return sprintf "%d-W%02d", $datetime->epiweek;
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
  unless (defined $lat && defined $long) {
    log_message("!! some unexpected problem with latlog arg '$latlong' to geo_coords_fields - look for latlong_error_s field in Solr docs");
    return (latlong_error_s => $latlong);
  }

  my $geohash = $gh->encode($lat, $long, 7);

  return (geo_coords => $latlong,
	  geohash_7 => $geohash,
	  geohash_6 => substr($geohash, 0, 6),
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

# sample_karyotype_fields
#
# given a list of all genotypes, if applicable, returns the following fields
#
# karyotype_s => a space delimited string concatenating the sorted karyotypes
#

sub sample_karyotype_fields {
  my @genotypes = @_;
  my @karyotypes;
  my %inversion_counts;
  foreach my $genotype (@genotypes) {
    my $genotype_type = $genotype->type; # cvterm/ontology term object
    # check if this genotype's type is the same as 'karyotype' or a child of it.
      if ($genotype_type->id == $karyotype_term->id ||
        $karyotype_term->has_child($genotype_type)) {
	# now get the "genotype" prop value
	# see https://www.vectorbase.org/popbio/assay/?id=VBA0000189 as an example
	foreach my $prop ($genotype->multiprops) {
          my @prop_terms = $prop->cvterms;
          push @karyotypes, $prop->value if ($prop_terms[0]->id == $genotype_term->id);
        }
      } elsif ($genotype_type->id == $chromosomal_inversion_term->id ||
        $chromosomal_inversion_term->has_child($genotype_type)) {
	my ($genotype_name, $genotype_value);
        foreach my $prop ($genotype->multiprops) {
          my @prop_terms = $prop->cvterms;
          $genotype_name = $prop->value if ($prop_terms[0]->id == $inversion_term->id);
          $genotype_value = $prop->value if ($prop_terms[0]->id == $genotype_term->id && $prop_terms[1]->id == $count_unit_term->id);
	}
	if (defined $genotype_name && defined $genotype_value) {
	  $inversion_counts{$genotype_name} = $genotype_value;
	}
      }
  }
  if (@karyotypes && keys %inversion_counts) {

    my @inversions = sort keys %inversion_counts;
    return (
	    karyotype_s => join(' ', sort @karyotypes),
	    inversions_assayed_ss => [ @inversions ],
	    map { ( "inversion_".$_."_count_i" => $inversion_counts{$_} ) } @inversions
	   );

  }

  return ();
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

sub sanitise_contact {
  my $contact = shift;
  $contact =~ s/\s+\(.+\)//;
  return $contact;
}

#
# if an empty $arrayref is passed, $value (e.g. 'no data') is pushed onto the array that is referenced
#
sub fallback_value {
  my ($arrayref, $value) = @_;
  unless (@$arrayref) {
    push @$arrayref, $value;
  }
}

#
# print JSON documents for main and autocomplete to chunked output files
#

#
# uses global variables $document_counter, $chunk_counter, $chunk_size, $chunk_fh, $needcomma
# (and the ac_* equivalents)
#

sub print_document {
  my ($prefix, $document, $ac_config) = @_;

  #
  # main document first
  #

  if (!defined $chunk_fh) { # start a new chunk
    $chunk_counter++;
    $chunk_fh = new IO::Compress::Gzip sprintf("$prefix-main-%02d.json.gz", $chunk_counter);
    die unless (defined $chunk_fh);
    print $chunk_fh "[\n";
    $needcomma = 0;
  }

  my $json_text = $json->encode($document);
  chomp($json_text);
  print $chunk_fh ",\n" if ($needcomma++);
  print $chunk_fh qq!$json_text\n!;

  $document_counter++;

  if ($document_counter % $chunk_size == 0) { # close the current chunk
    print $chunk_fh "]\n";
    close($chunk_fh);
    undef $chunk_fh;
  }

  #
  # autocomplete next
  #
  my $bundle = $document->{bundle};
  my $has_abundance_data = $document->{has_abundance_data_b};
  my $phenotype_type = $document->{phenotype_type_s};
  my $genotype_type = $document->{genotype_type_s};

  if ($ac_config && $bundle && $ac_config->{$bundle}) {
    my $config = $ac_config->{$bundle};
    # process $document to find fields to add for a/c
    foreach my $field (keys %{$document}) {
      if (exists $config->{$field}) {
	my $type = $config->{$field}{type};
	my $typedot = $type; $typedot =~ s/\s/./g;

	my @common_fields =
	  (
	   type => $type,
	   bundle => $bundle,
	   field => $field,
	   ( $has_abundance_data ? (has_abundance_data_b => 1) : () ),
	   ( defined $phenotype_type ? (phenotype_type_s => $phenotype_type) : () ),
	   ( defined $genotype_type ? (genotype_type_s => $genotype_type) : () ),
	   geo_coords => $document->{geo_coords}, # used for "local suggestions"
	  );

	if ($config->{$field}{multi} || $config->{$field}{cvterms}) {
	  my $last_was_accession;
	  for (my $i=0; $i<@{$document->{$field}}; $i++) {
	    my $text = $document->{$field}[$i];
	    my $is_accession = $text =~ /^\w+:\d+$/; # is this an ontology term accession? e.g. VBsp:0012345
	    my $ac_document =
	      ohr(
		  id => "$document->{id}.$typedot.$i",
		  textsuggest => $text,
		  @common_fields,
		  textboost => $config->{$field}{cvterms} && $i == 0 ? 100 : 20,
		  is_synonym => $config->{$field}{cvterms} && $i>0 &&
		                !$is_accession && !$last_was_accession ? 'true' : 'false'
		 );
	    $last_was_accession = $is_accession;
	    print_ac_document($prefix, $ac_document);
	  }
	} else {
	  my $ac_document =
	    ohr(
		id => "$document->{id}.$typedot",
		textsuggest => $document->{$field},
		@common_fields
	       );
	  print_ac_document($prefix, $ac_document);
	}
      }
    }
  }
}


#
# the following is a bit cut and paste-y
# could do all the document and chunk counts hashed on $prefix
# and then just use print_document for both?
#
sub print_ac_document {
  my ($prefix, $ac_document) = @_;

  if (!defined $ac_chunk_fh) {	# start a new chunk
    $ac_chunk_counter++;
    $ac_chunk_fh = new IO::Compress::Gzip sprintf("$prefix-ac-%02d.json.gz", $ac_chunk_counter);
    die unless (defined $ac_chunk_fh);
    print $ac_chunk_fh "[\n";
    $ac_needcomma = 0;
  }

  my $ac_json_text = $json->encode($ac_document);
  chomp($ac_json_text);
  print $ac_chunk_fh ",\n" if ($ac_needcomma++);
  print $ac_chunk_fh qq!$ac_json_text\n!;
  $ac_document_counter++;

  if ($ac_document_counter % $ac_chunk_size == 0) { # close the current chunk
    print $ac_chunk_fh "]\n";
    close($ac_chunk_fh);
    undef $ac_chunk_fh;
  }
}

#
# log_message
#
# write $message to the global logfile and increment a counter
#


sub log_message {
  my ($message) = @_;
  open LOG, ">>$log_filename" || die "can't write to $log_filename\n";
  print LOG "$message\n";
  close(LOG);
  $log_size++;
}
