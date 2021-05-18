#!/usr/bin/env perl
# -*- mode: cperl -*-
#
# TO DO:
# 1. make a drop-list for certain prop terms, such as age => F1, age => F0 adults etc
# 2. Process Iowa 2013-2014 (VBP0000194) to split mixed_sex samples into male and female
#    This will require copying ALL assays over to new samples
# 3. handle multiple values for attractants
# 4. Add units=day for Source Characteristic "duration of specimen collection (OBI:OBI_0002988)"
#
# usage: bin/restructure_for_veupath.pl [ --dry-run ] [ --verbose ] [ --limit 20 ] --projects VBP0000nnn,VBP0000mmm --mapping_csv popbio-term-usage-XXX.csv
#
#        also allows comma-separated project IDs and also: --projects ALL
#
# options:
#   --dry-run              : rolls back transaction and doesn't insert into db permanently
#   --verbose              : show non-error progress logging
#   --limit N              : process max N samples per project
#   --dump-isatab          : dump processed project(s) to isatab files in <isatab-prefix>-<projectID> directories
#   --isatab-prefix        : prefix of optional isatab output directories
#

use 5.016; # for JSON::Path
use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use Getopt::Long;
use utf8::all;
use Data::Dumper;
use JSON;
use File::Slurp;
use JSON::Path;
$JSON::Path::Safe = 0;  # needed for sub-expressions only foo[?(expr)]
use List::MoreUtils qw(uniq);
use File::Temp qw(tempdir);

use Text::CSV::Hashify;

use aliased 'Bio::Chado::VBPopBio::Util::Multiprop';


my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $cvterms = $schema->cvterms;
my $dbxrefs = $schema->dbxrefs;
my $dry_run = 1;  # while in development
my $project_ids;
my $verbose;
my $limit;
my $mapping_file = 'popbio-term-usage-VB-2019-08-master.csv';
my $ir_attr_file = 'popbio-term-usage-VB-2019-08-insecticide-attrs.csv';
my $isatab_prefix = './temp-isatab-';  # will be suffixed with project ID if
my $dump_isatab = 0;                   # --dump_isatab provided on commandline
my $error_file;                        # ALSO send STDERR to this file (clobbered not appended)

GetOptions("dry-run|dryrun"=>\$dry_run,
	   "projects=s"=>\$project_ids,
           "verbose"=>\$verbose,
           "limit=i"=>\$limit,
           "mapping_file|mapping_csv|mapping-file|mapping-csv=s"=>\$mapping_file,
           "ir_file|ir_csv|ir-attrs|ir-attrs-csv=s"=>\$ir_attr_file,
           "dump_isatab|dump-isatab"=>\$dump_isatab,
           "isatab_prefix|isatab-prefix=s"=>\$isatab_prefix,
           "error_file|error-file=s"=>\$error_file,
	  );

die "can't --dump-isatab if --limit X is given\n" if ($dump_isatab && $limit);

die "need to give --projects PROJ_ID(s) and --mapping CSV_FILE params\n" unless (defined $project_ids && defined $mapping_file);

if ($error_file) {
  *STDERR->push_layer(tee => $error_file);
}

die "mapping file ($mapping_file) doesn't exist\n" unless (-s $mapping_file);
my $hashify = Text::CSV::Hashify->new( {
                                        file        => $mapping_file,
                                        format      => 'aoh',
                                        # array of hashes because column C "Term accession"
                                        # is not unique (except with column F, Object type)
                                       } );

my $aoh = $hashify->all();
# now make a lookup using the underscore-style ID at the first level
# then the "Object type" as the second level (value: NdProtocol, Genotype, NdExperiment, NdExperimentProp etc)
# value is the hash of row data from the CSV file
my $main_term_lookup = {};
foreach my $row (@$aoh) {
  my $colon_id = $row->{'Term accession'};
  my $underscore_id = underscore_id($colon_id, 'process main lookup');
  my ($object_type) = $row->{'Object type'} =~ /(\w+)$/;
  die "duplicate row for $underscore_id $object_type" if (exists $main_term_lookup->{$underscore_id}{$object_type});
  $main_term_lookup->{$underscore_id}{$object_type} = $row;
}


# Now make a lookup for the second sheet of the spreadsheet workbook
# first key: attr accession in underscore style (e.g. VBcv_0000732 (LC50))
# second key: units accession in underscore style (e.g. UO_0000031 (minute))
# value = hash of row data from the file
my $hashify_ir = Text::CSV::Hashify->new( {
                                           file        => $ir_attr_file,
                                           format      => 'aoh',
                                           # array of hashes because there is no unique ID column
                                          } );
my $aoh_ir = $hashify_ir->all();
my $ir_attr_lookup = {};
foreach my $row (@$aoh_ir) {
  my $attr_id = underscore_id($row->{'Term accession'}, 'process ir lookup attr');
  my $unit_id = underscore_id($row->{'Units ID'}, 'process ir lookup unit');
  die "problem with IR attr lookup file" unless ($attr_id && $unit_id);
  $ir_attr_lookup->{$attr_id}{$unit_id} = $row;
}

###
# manual lookup for biochem units
#
# attr_id => unit_id => faked row from lookup table
my $biochem_units_lookup =
  {
   'VBcv_0001116' => { 'UO_0000190' => { 'OBO ID' => 'EUPATH_0043140', 'OBO Label' => 'new mean ratio term' } }, # mean ratio
   'VBcv_0001124' => { 'UO_0000190' => { 'OBO ID' => 'EUPATH_0043141', 'OBO Label' => 'new median ratio term' } }, # median ratio
   'VBcv_0001111' => { 'UO_0000187' => { 'OBO ID' => 'EUPATH_0043142', 'OBO Label' => 'new fraction greater than 99th percentile term' } }, # percent > 99th percentile
  };

###
# special prop terms not to be mapped
#
my $do_not_map_terms =
  {
   $schema->types->date->id => 1,
   $schema->types->start_date->id => 1,
   $schema->types->end_date->id => 1,
   $schema->types->study_design->id => 1,
   $schema->types->project_tags->id => 1,
  };

###
# prop terms to be retired
#
my $retire_me_terms =
  {
   $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0000701' })->id => 1, # country
   $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001129' })->id => 1, # ADM1
   $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001130' })->id => 1, # ADM2
  };


###
# constant ontology terms used below
#
my $ir_assay_base_term = $cvterms->find_by_accession({ term_source_ref => 'MIRO',
                                                       term_accession_number => '20000058' }) || die;

my $ir_biochem_assay_base_term = $cvterms->find_by_accession({ term_source_ref => 'MIRO',
							       term_accession_number => '20000003' }) || die;


my $variant_frequency_term = $cvterms->find_by_accession({ term_source_ref => 'SO',
                                                           term_accession_number => '0001763' }) || die;

my $count_unit_term = $cvterms->find_by_accession({ term_source_ref => 'UO',
                                                    term_accession_number => '0000189' }) || die;


my $arthropod_infection_status_term = $cvterms->find_by_accession({ term_source_ref => 'VSMO',
                                                                    term_accession_number => '0000009' }) || die;

my $parent_term_of_present_absent = $cvterms->find_by_accession({ term_source_ref => 'PATO',
                                                                  term_accession_number => '0000070' }) || die;

my $blood_meal_term = $cvterms->find_by_accession({ term_source_ref => 'VBcv',
                                                    term_accession_number => '0001003' }) || die;

my $blood_meal_source_term = $cvterms->find_by_accession({ term_source_ref => 'VBcv',
                                                           term_accession_number => '0001004' }) || die;

my $equivocal_term = $cvterms->find_by_accession({ term_source_ref => 'VBcv',
                                                   term_accession_number => '0001127' }) || die;

my $mutated_protein_term = $cvterms->find_by_accession({ term_source_ref => 'IDOMAL',
                                                         term_accession_number => '50000004' }) || die;

my $wild_type_allele_term = $cvterms->find_by_accession({ term_source_ref => 'IRO',
                                                          term_accession_number => '0000001' }) || die;

my $simple_sequence_length_polymorphism_term = $cvterms->find_by_accession({ term_source_ref => 'SO',
                                                                             term_accession_number => '0000207' }) || die;

my $chromosomal_inversion_term = $cvterms->find_by_accession({ term_source_ref => 'SO', 
                                                               term_accession_number => '1000030' }) || die;

my $genotyping_by_sequencing = $cvterms->find_by_accession({ term_source_ref => 'EFO',
                                                                     term_accession_number => '0002771' }) || die;

my $genotyping_by_array = $cvterms->find_by_accession({ term_source_ref => 'EFO',
                                                        term_accession_number => '0002767' }) || die;

my $DNA_barcode_assay = $cvterms->find_by_accession({ term_source_ref => 'VBcv',
                                                      term_accession_number => '0001025' }) || die;

my $microsatellite_term = $cvterms->find_by_accession({ term_source_ref => 'SO',
                                                        term_accession_number => '0000289' }) || die;

my $length_term = $cvterms->find_by_accession({ term_source_ref => 'PATO',
                                                term_accession_number => '0000122' }) || die;


### some globals related to placeholder-making and other caches
my $last_accession_number = 90000001;
my $processed_entity_props = {};
my $processed_protocol = {};
my ($placeholder_cv, $new_insecticide_heading, $attractant_heading_term, $device_heading_term);

# disable buffering of standard output so the progress update is "live"
$| = 1;

# run everything in a transaction
$schema->txn_do_deferred
  ( sub {
      # some, cough, globals...
      $placeholder_cv = $schema->cvs->find_or_create({ name => 'Placeholder CV' });
      $new_insecticide_heading = main_map_old_id_to_new_term('MIRO_10000239', 'insecticidal substance', 'NdExperimentprop', 'new_insecticide_heading');
      $attractant_heading_term = get_cvterm('EUPATH_0043001', 'attractant');
      $device_heading_term = get_cvterm('OBI_0000968', 'device');

      # make these in the transaction so they can be rolled back
      my $assayed_pathogen_term = get_cvterm('EUPATH_0000756', 'assayed pathogen');
      $do_not_map_terms->{$assayed_pathogen_term->id} = 1;
      my $pathogen_presence_term = get_cvterm('EUPATH_0010889', 'pathogen presence');
      $do_not_map_terms->{$pathogen_presence_term->id} = 1;
      my $assayed_bm_host_term = make_placeholder_cvterm('OBI_0002995', 'blood meal host organism');
      $do_not_map_terms->{$assayed_bm_host_term->id} = 1;
      my $bm_host_presence_term = make_placeholder_cvterm('OBI_0002994', 'blood meal host presence');
      $do_not_map_terms->{$bm_host_presence_term->id} = 1;


      # handle the projects commandline arg
      my @projects = ();
      if ($project_ids eq 'ALL') {
        @projects = $schema->projects->all;
      } else {
        foreach my $project_id (split /\W+/, $project_ids) {
          my $project = $schema->projects->find_by_stable_id($project_id);
          unless ($project) {
            $schema->defer_exception("couldn't find project '$project_id'");
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

        process_entity_props($project, 'Projectprop');
        map {
          my $new_status = main_map_old_term_to_new_term($_->type, 'Pub', "Pub type");
          if ($new_status->id ne $_->type->id) {
            $_->type($new_status);
            $_->update;
          }
        } $project->publications;

        my $samples = $project->stocks;
	while (my $sample = $samples->next()) {

          process_entity_props($sample, 'Stockprop');
          # map the sample->type
          my $new_type = main_map_old_term_to_new_term($sample->type, 'Stock', "Sample type");
          if ($new_type->id ne $sample->type->id) {
            $sample->type($new_type);
            $sample->update;
          }

          # loop through all four types of assay
          my $collections = $sample->field_collections;
          while (my $assay = $collections->next()) {
            # TO DO: handle collection protocol old->new and add extra device prop when needed
            process_entity_props($assay, 'NdExperimentprop');
            # don't process assay type because it kills project->field_collections() ### process_assay_type($assay);
            process_assay_protocols($assay);

            # collection geolocation itself has props but we may want to remove these
            # and rely instead only on the terms we assign from lat/long lookup
            process_entity_props($assay->nd_geolocation, 'NdGeolocationprop');
          }

          my $species_assays = $sample->species_identification_assays;
          while (my $assay = $species_assays->next()) {
            # TO DO: map protocol old->new

            process_entity_props($assay, 'NdExperimentprop');
            process_assay_type($assay);
            process_assay_protocols($assay);
          }

          my $phenotype_assays = $sample->phenotype_assays;
          while (my $assay = $phenotype_assays->next()) {

            if (is_insecticide_resistance_assay($assay)) {
              #
              # special treatment of phenotypes for Insecticide resistance assays
              # (needs special mapping of phenotype.attr+unit to assay_characteristics)
              #
              my $phenotypes = $assay->phenotypes;
              while (my $phenotype = $phenotypes->next()) {
                my $object_type = object_type($phenotype);

                my $data = $phenotype->as_data_structure;
                # die Dumper($data);
                # get the measured attribute (e.g. LC50 or mortality)
                my $attr_id = underscore_id($data->{attribute}{accession}, 'IR phenotype data attr');
                my $unit_id = underscore_id($data->{value}{unit}{accession}, 'IR phenotype data unit');
                my $new_value = clean_value($data->{value}{text});
                unless ($attr_id && $unit_id && length($new_value)) {
                  $schema->defer_exception("Phenotype for ".$assay->stable_id." missing one or more of required attribute, value and unit");
                  next;
                }
                # look up old->new mapping
                if (my $lookup_row = $ir_attr_lookup->{$attr_id}{$unit_id}) {
                  # is there a new ontology ID
                  if ($lookup_row->{'OBO ID'}) {
                    my $new_attr_id = underscore_id($lookup_row->{'OBO ID'}, "Missing or invalid term ID for '$data->{attribute}{name}' '$data->{value}{unit}{name}' in IR lookup");
                    if ($new_attr_id) {
                      my $label = $lookup_row->{'OBO Label'};
                      my $unit_lookup_row = $biochem_units_lookup->{$attr_id}{$unit_id} || $main_term_lookup->{$unit_id}{$object_type};
                      if ($unit_lookup_row) {
                        my $new_unit_id = underscore_id($unit_lookup_row->{'OBO ID'}, "Missing or invalid term ID for '$data->{value}{unit}{name}' '$object_type' in main (or biochem) lookup");
                        my $new_unit_label = $unit_lookup_row->{'OBO Label'};
                        if ($new_unit_id) {
                          # print "going to map from IR phenotype $attr_id '$new_value' $unit_id to characteristic $new_attr_id ($label) $new_unit_id ($new_unit_label)\n";
                          my $new_attr_term = get_cvterm($new_attr_id, $label);
                          my $new_unit_term = get_cvterm($new_unit_id, $new_unit_label);
                          # add the new assay characteristic, e.g. "LC50 in mass density unit", 1.5, "mg/l"
                          $assay->add_multiprop(my $p = Multiprop->new(cvterms=>[$new_attr_term, $new_unit_term],
                                                                       value=>$new_value));
                          # before removing the phenotype, see if it has any properties that we might be losing
                          my @props = $phenotype->multiprops;
                          if (@props) {
                            my $prop_summary = join "; ", map { $_->as_string } @props;
                            $schema->defer_exception("Phenotype of ".$assay->stable_id." has prop(s) not dealt with: $prop_summary");
                          }
                          # remove the phenotype
                          $phenotype->delete;
                        } else {
                          $schema->defer_exception_once("No 'OBO ID' for unit '$unit_id' in main lookup");
                        }
                      } else {
                        $schema->defer_exception_once("No row in main (or biochem) lookup for '$unit_id' '$object_type'");
                      }
                    }
                  } else {
                    $schema->defer_exception_once("IR lookup 'OBO ID' column empty for '$attr_id' '$unit_id'");
                  }
                } else {
                  $schema->defer_exception_once("No row in IR lookup for '$attr_id' '$unit_id'");
                }
              }
              # do some generic old->new mapping (last one has to be done after is_insecticide_resistance_assay() call)
              process_entity_props($assay, 'NdExperimentprop');
              process_assay_type($assay);
              process_assay_protocols($assay);
            } else {

              # process remaining phenotype assays - phenotype-wise (as in create_json_for_solr.pl)

              # process each phenotype into a new assay (which will require a modified external_id - hence the counter)
              my $counter = 1;
              foreach my $phenotype ($assay->phenotypes) {
                my $new_assay = copy_assay($assay, $sample, $counter++);

                # now process the phenotype into new_assay props
                # don't map old terms to new terms yet (do at end with process_entity_props)
                if (is_pathogen_infecton_phenotype($phenotype)) {
                  # assayed pathogen (value = species term)
                  my $assayed_pathogen_prop = Multiprop->new(cvterms => [ $assayed_pathogen_term, $phenotype->attr ]);
                  my $added_ok = $new_assay->add_multiprop($assayed_pathogen_prop);

                  my $pathogen_presence_prop = Multiprop->new(cvterms => [ $pathogen_presence_term, $phenotype->cvalue ]);
                  my $added_ok2 = $new_assay->add_multiprop($pathogen_presence_prop);

                  $schema->defer_exception_once("Couldn't add assayed_pathogen_prop to new assay") unless ($added_ok);
                } elsif (is_blood_meal_host_id_phenotype($phenotype)) {
                  my $assayed_bm_host_prop = Multiprop->new(cvterms => [ $assayed_bm_host_term, $phenotype->attr ]);
                  my $added_ok = $new_assay->add_multiprop($assayed_bm_host_prop);

                  my $bm_host_presence_prop = Multiprop->new(cvterms => [ $bm_host_presence_term, $phenotype->cvalue ]);
                  my $added_ok2 = $new_assay->add_multiprop($bm_host_presence_prop);
                } else {
                  $schema->defer_exception_once("Unhandled phenotype '".$phenotype->name."' for assay ".$assay->stable_id);
                }

                # and then move them to the new assay
                # (need to 'clone' the multiprop to remove the rank property)
                map { $new_assay->add_multiprop(Multiprop->new(cvterms=>[$_->cvterms], value=>$_->value)) } $phenotype->multiprops;

                # map any old terms to new terms
                process_entity_props($new_assay, 'NdExperimentprop');
                process_assay_type($new_assay);
                process_assay_protocols($new_assay);
              }
              $assay->delete;
            }
          }

          my $genotype_assays = $sample->genotype_assays;
          while (my $assay = $genotype_assays->next()) {

            if (is_kdr_like_genotype_assay($assay)) {
              process_entity_props($assay, 'NdExperimentprop');
              process_assay_type($assay);
              process_assay_protocols($assay);
              my $num_genotypes_processed = 0;
              foreach my $genotype ($assay->genotypes) {
                # move $genotype->type and the prevalence value into assay props
                my $old_type = $genotype->type;
                my $new_variable = main_map_old_term_to_new_term($old_type, 'Genotype', "genotype to assay variable");
                my ($genotype_value, $genotype_unit);
                foreach my $prop ($genotype->multiprops) {
                  my @prop_terms = $prop->cvterms;
                  if ($prop_terms[0]->id == $count_unit_term->id ||
                      $prop_terms[0]->id == $variant_frequency_term->id) {
                    $genotype_value = $prop->value;
                    $genotype_unit = $prop_terms[-1];
                  } else {
                    $schema->defer_exception_once("genotype has unhandled prop: ".$prop->as_string);
                  }
                }
                if (defined $genotype_value && $genotype_unit) {
                  if ($new_variable->definition !~ /^id-less/) {
                    # warn sprintf "old type '%s' to new variable '%s' value '%s' unit '%s'\n", $old_type->name, $new_variable->name, $genotype_value, $genotype_unit->name;
                    # map unit to new term if needed
                    my $new_genotype_unit = main_map_old_term_to_new_term($genotype_unit, 'Genotypeprop', "genotype to assay variable, units mapping");
                    my $new_assay_prop = Multiprop->new(cvterms=>[ $new_variable, $new_genotype_unit ], value=>$genotype_value);
                    my $success = $assay->add_multiprop($new_assay_prop);
                    if ($success) {
                      $genotype->delete;
                      $num_genotypes_processed++;
                    } else {
                      $schema->defer_exception("Error adding genotype as assay variable for ".$assay->stable_id);
                    }
                  }
                } else {
                  $schema->defer_exception(sprintf "incomplete genotype information for %s's genotype '%s'", $assay->stable_id, $genotype->name);
                }
              }
              if ($num_genotypes_processed == 0) {
                # discard whole assays where the genotypes did not have new terms mapped to them
                # (the $new_variable has a definition starting with 'id-less')
                $assay->delete;
                $schema->defer_exception(sprintf "INFO: removed genotype assay %s which only had unmapped genotypes", $assay->stable_id);
              } elsif ($assay->genotypes->count > 0) {
                # sanity check that there are no genotypes remaining on the assay
                $schema->defer_exception(sprintf "ERROR: unexpected incomplete genotype processing for %s", $assay->stable_id);
              }

            } elsif (is_microsatellite_assay($assay)) {
              #
              # do the same assay cloning as with blood meal/pathogen assays
              #

              # do we store the two polymorphism length results (one for each chromosome of diploid genome) in ONE assay or TWO?
              # one assay would be something like microsat_length1 microsat_length2
              # DECISION: going to store both lengths in one Characteristic - semicolon delimited
              

              # go through all genotypes (microsat name + length pairs)
              # and store all the lengths (up to two) per name

              my %locus2lengths;  #  locus_name => [ 123, 126 ]
              foreach my $genotype ($assay->genotypes) {
                if ($genotype->type->name eq 'simple_sequence_length_variation') {
                  my ($mname, $mlen);
                  foreach my $prop ($genotype->multiprops) {
                    if (($prop->cvterms)[0]->name eq 'microsatellite') {
                      $mname = $prop->value;
                    } elsif (($prop->cvterms)[0]->name eq 'length') {
                      $mlen = $prop->value;
                    } else {
                      $schema->defer_exception_once("Unexpected genotype props in microsatellite assay");
                    }
                  }
                  if ($mname && defined $mlen) {
                    push @{$locus2lengths{$mname}}, $mlen;
                  } else {
                    $schema->defer_exception_once("Missing name+length genotype props in microsatellite assay");
                  }
                } else {
                  $schema->defer_exception_once("Unexpected genotype type in microsatellite assay");
                }

              }
              foreach my $mname (sort keys %locus2lengths) {
                my $new_assay = copy_assay($assay, $sample, $mname);
                # add a microsatellite property and length property
                my $microsat_prop = Multiprop->new(cvterms=>[$microsatellite_term], value=>$mname);
                $new_assay->add_multiprop($microsat_prop);
                my $length_prop = Multiprop->new(cvterms=>[$length_term], value=>join(';', @{$locus2lengths{$mname}}));
                $new_assay->add_multiprop($length_prop);
              }

              $assay->delete;

            } elsif (is_chromosomal_inversion_assay($assay)) {
              #
              # store all the individual inversion counts in ONE assay - but this needs quite a few NEW TERMS
              # (get unique terms, e.g. 2Rj 2Rd etc, from legacy site site search downloads)
              #
              $schema->defer_exception_once("TO DO chromosomal inversion handling");

            } elsif (is_this_kind_of_assay($assay, $genotyping_by_sequencing) || is_this_kind_of_assay($assay, $genotyping_by_array)) {
              # do nothing special - these assays don't have child Genotype objects
              process_entity_props($assay, 'NdExperimentprop');
              process_assay_type($assay);
              process_assay_protocols($assay);

            } elsif (is_this_kind_of_assay($assay, $DNA_barcode_assay)) {
              # for now, delete the genotype object (there should only be one per assay)
              # could copy over the genotype props but we'll wait to see what is happening in VEuPathDB as a whole
              map { $_->delete } $assay->genotypes;
              process_entity_props($assay, 'NdExperimentprop');
              process_assay_type($assay);
              process_assay_protocols($assay);
            } else {
              $schema->defer_exception(sprintf "Unhandled genotype assay %s", $assay->stable_id);
            }
          }

          # TO DO: sample manipulations?? or at least, remove them


          $done_samples++;
          last if ($limit && $done_samples >= $limit);
	}

	$project->update_modification_date();

        if (!$limit || $done_samples < $limit) {
          my $output_dir = $dump_isatab ? $isatab_prefix.$project_id : tempdir(CLEANUP => 1);
          my $isatab = $project->write_to_isatab({ directory=>$output_dir, protocols_first=>1 });
          warn "wrote $project_id ISA-Tab to $output_dir\n";
          my $isatab_json = encode_json($isatab);
          write_file("$output_dir/isatab.json", $isatab_json);

          # now do checks for mixed units
          my $source_chars = JSON::Path->new('$.studies[0].sources[*].characteristics');
          my @source_chars = $source_chars->values($isatab);
          my $source_units = summarise_units(@source_chars);
          warn_units($source_units, "Collections", $schema);

          my $sample_chars = JSON::Path->new('$.studies[0].sources[*].samples[*].characteristics');
          my @sample_chars = $sample_chars->values($isatab);
          my $sample_units = summarise_units(@sample_chars);
          warn_units($sample_units, "Samples", $schema);

          my $study_assay_measurement_types = JSON::Path->new('$.studies[0].study_assays[*].study_assay_measurement_type');
          my @study_assay_measurement_types = $study_assay_measurement_types->values($isatab);

          my $study_assays = JSON::Path->new('$.studies[0].study_assays');
          my $assay_chars = JSON::Path->new('$.[*].samples[*].assays[*].characteristics');

          my @study_assays = $study_assays->values($isatab);

          foreach my $study_assay_measurement_type (uniq(@study_assay_measurement_types)) {
            # filter without using JSON::Path subexpressions, due to a colon-related bug in JSON::Path
            my @this_type_assays = grep { $_->{study_assay_measurement_type} eq $study_assay_measurement_type } @{$study_assays[0]};
            my @assay_chars = $assay_chars->values(\@this_type_assays);
            my $units_summary = summarise_units(@assay_chars);
            warn_units($units_summary, $study_assay_measurement_type, $schema);
          }

        } else {
          $schema->defer_exception("WARNING: ISA-Tab not dumped or checked for mixed units because number of samples processed reached --limit $limit");
        }
      }
      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );

sub underscore_id {
  my ($id, @debug_info) = @_;
  # already underscored and looks like an onto id?
  if ($id =~ /^\w+?_\w+$/) {
    # all good - do nothing
  } elsif ($id =~ /^\w+?:(\w+?_\w+)$/) { # already underscored AND colon prefixed - just return the latter bit
    $id = $1;
  } elsif ($id =~ /^\w+?:\w+$/) { # regular ONTO:0012345 style
    $id =~ s/:/_/;
  } elsif ($id) {
    $schema->defer_exception_once("Bad ID '$id' - @debug_info");
  } else {
    $schema->defer_exception_once("No ID provided - @debug_info");
  }
  return $id;
}

sub object_type {
  my ($object) = @_;
  my $ref = ref($object);
  my ($type) = $ref =~ /(\w+)$/;
  die "bad object type '$ref'" unless ($type);
  return $type;
}


#
# makes a shallow-ish copy of an assay
#
# copied: protocols, props
# not copied: genotypes or phenotypes
#
# new assay is linked back to the provided sample
# the suffix is appended to the external_id to make it unique (in case a stable_id is required)
#
sub copy_assay {
  my ($assay, $sample, $suffix) = @_;
  my $new_assay = $assay->copy();
  # make a (presumably) new external_id (.1, .2 etc)
  $new_assay->external_id($assay->external_id.'.'.$suffix);
  # link it back to the sample
  $new_assay->add_to_stocks($sample, { type_id => $schema->types->assay_uses_sample->id });
  # link to the protocol(s) of the original assay
  map {
    my $linker = $new_assay->find_or_create_related('nd_experiment_protocols', {  nd_protocol => $_ } );
  } $assay->protocols;
  # copy assay props over
  map { $new_assay->add_multiprop(Multiprop->new(cvterms=>[$_->cvterms], value=>$_->value)) } $assay->multiprops;

  return $new_assay;
}


sub is_this_kind_of_assay {
  my ($assay, $protocol_term) = @_;

  my @protocol_types = map { $_->type } $assay->protocols->all;
  if (grep { $_->id == $protocol_term->id || $protocol_term->has_child($_) } @protocol_types) {
    return 1;
  } else {
    return 0;
  }
}

sub is_kdr_like_genotype_assay {
  my ($assay) = @_;
  my ($count_positive, $count_total) = (0, 0);
  foreach my $genotype ($assay->genotypes) {
    my $genotype_type = $genotype->type;
    $count_total++;
    $count_positive++ if ($mutated_protein_term->has_child($genotype_type) || $wild_type_allele_term->has_child($genotype_type));
  }
  return $count_positive > 0 && $count_positive == $count_total;
}

sub is_microsatellite_assay {
  my ($assay) = @_;
  my ($count_positive, $count_total) = (0, 0);
  foreach my $genotype ($assay->genotypes) {
    my $genotype_type = $genotype->type;
    $count_total++;
    $count_positive++ if ($genotype_type->id == $simple_sequence_length_polymorphism_term->id ||
                          $simple_sequence_length_polymorphism_term->has_child($genotype_type));
  }
  return $count_positive > 0 && $count_positive == $count_total;
}

sub is_chromosomal_inversion_assay {
  my ($assay) = @_;
  my ($count_positive, $count_total) = (0, 0);
  foreach my $genotype ($assay->genotypes) {
    my $genotype_type = $genotype->type;
    $count_total++;
    $count_positive++ if ($genotype_type->id == $chromosomal_inversion_term->id ||
                          $chromosomal_inversion_term->has_child($genotype_type));
  }
  return $count_positive > 0 && $count_positive == $count_total;
}

sub is_insecticide_resistance_assay {
  my ($assay) = @_;
  my @protocol_types = map { $_->type } $assay->protocols->all;

  if (grep { $_->id == $ir_assay_base_term->id ||
	       $ir_assay_base_term->has_child($_) ||
                 $ir_biochem_assay_base_term->has_child($_)
               } @protocol_types) {
    return 1;
  }
}

sub is_pathogen_infecton_phenotype {
  my ($phenotype) = @_;
  my ($observable, $attribute, $cvalue) = ($phenotype->observable, $phenotype->attr, $phenotype->cvalue);
  return (defined $observable && $observable->id == $arthropod_infection_status_term->id &&
          defined $attribute && # no further tests here but expecting a species term
          defined $cvalue &&
          ($parent_term_of_present_absent->has_child($cvalue) || $cvalue->id == $equivocal_term->id));

}

sub is_blood_meal_host_id_phenotype {
  my ($phenotype) = @_;
  my ($observable, $attribute, $cvalue) = ($phenotype->observable, $phenotype->attr, $phenotype->cvalue);
  return (defined $observable && ($observable->id == $blood_meal_term->id || $observable->id == $blood_meal_source_term->id) &&
          defined $attribute && $blood_meal_source_term->has_child($attribute) &&
          defined $cvalue && $parent_term_of_present_absent->has_child($cvalue));
}


sub clean_value {
  my ($value) = @_;
  if (defined $value) {
    # remove trailing and leading space
    $value =~ s/\s+$//;
    $value =~ s/^\s+//;
  }
  return $value;
}

# assume id provided is underscore delimited
# it will throw an exception and return a dummy placeholder term if term not found
sub get_cvterm {
  my ($id, $placeholder_name) = @_;
  my ($prefix, $accession) = $id =~ /(\w+?)_(\d+)/;
  if ($prefix && defined $accession && length($accession)) {
    my $term = $cvterms->find_by_accession({ term_source_ref => $prefix,
                                             term_accession_number => $accession });
    if ($term) {
      return $term;
    }
  } else {
    $schema->defer_exception_once("get_cvterm('$id') was provided with a poorly formed term ID");
  }
  return make_placeholder_cvterm($id, $placeholder_name || "placeholder for $id");
}

#
# make placeholder term and return it
#
sub make_placeholder_cvterm {
  my ($id, $name) = @_;
  # first look up by name if already made
  my $already_made_term = $cvterms->find({ name => $name,
                                           cv_id => $placeholder_cv->id });
  if ($already_made_term) {
    return $already_made_term;
  }

  # otherwise make it
  # don't let these get committed to the database
  my $nid = $id || 'n/a';
  $schema->defer_exception_once("Making placeholder for '$name' ($nid)");

  my $acc = $id || sprintf "EUPATH_%d", $last_accession_number++;
  my $definition_prefix = $id ? '' : 'id-less ';

  my ($prefix, $number) = $acc =~ /^([A-Z_]+|VEuGEO|NCBITaxon)_(\d+)/;
  die "No parseable prefix for $acc" unless ($prefix);
  my $db = $schema->dbs->find_or_create({ name => $prefix });

  my $new_cvterm =
    $dbxrefs->find_or_create( { accession => $number,
                                db => $db },
                              { join => 'db' })->
                                find_or_create_related('cvterm',
                                                       { name => $name,
                                                         definition => $definition_prefix."placeholder for term '$name'",
                                                         cv => $placeholder_cv
                                                       });

  return $new_cvterm;
}


#
# process props (aka characteristics) from all assays, samples & projects (any others?)
# and perform specialised transformations where necessary (e.g. insecticide concentrations)
#
# works inplace/destructively on the item's multiprops
#
# $proptype would be NdExperimentprop for assays, Stockprop for samples and
# Projectprop for projects
#


sub process_entity_props {
  my ($entity, $proptype) = @_;

  # don't process the same entity more than once
  # TO DO: handle this between different processes (same geolocation could be shared by different projects)
  return if ($processed_entity_props->{$entity->id}{$proptype}++);

  my @multiprops = $entity->multiprops;

  foreach my $multiprop (@multiprops) {
    my @orig_cvterms = $multiprop->cvterms;
    #
    # special processing for insecticide-X-concentration-units-Y
    #
    # going to do checks by name and not by accession because this is a one-time script
    # (doesn't matter if the terms change in the future)
    if ($orig_cvterms[0]->name eq 'insecticidal substance' && $orig_cvterms[2]->name eq 'concentration of') {
      my ($old_insecticide_heading, $old_insecticide_term, $concentration_of, $old_units_term) = @orig_cvterms;
      my $new_insecticide_term = main_map_old_term_to_new_term($old_insecticide_term, $proptype, "insecticide special main");
      my $new_insecticide_prop = Multiprop->new(cvterms=>[$new_insecticide_heading, $new_insecticide_term]);

      my $old_units_underscore_id = underscore_id($old_units_term->dbxref->as_string(), "insecticide special units");
      my $lookup_row = $ir_attr_lookup->{PATO_0000033}{$old_units_underscore_id};
      if ($lookup_row && $lookup_row->{'OBO ID'}) {
        my $new_concentration_underscore_id = underscore_id($lookup_row->{'OBO ID'}, "new insecticide concentration term for $old_units_underscore_id") || $old_units_underscore_id;
        my $new_concentration_term = get_cvterm($new_concentration_underscore_id, $lookup_row->{'OBO Label'});

        my $new_unit_term = main_map_old_id_to_new_term($old_units_underscore_id, $old_units_term->name, $proptype, "new insecticide unit term for $old_units_underscore_id");

        my $new_concentration_prop = Multiprop->new(cvterms=>[$new_concentration_term, $new_unit_term], value=>$multiprop->value);

        my $ok_deleted = $entity->delete_multiprop($multiprop);
        if ($ok_deleted) {
          my $ok_added1 = $entity->add_multiprop($new_insecticide_prop);
          unless ($ok_added1) {
            $schema->defer_exception("Problem adding multiprop: (".$new_insecticide_prop->as_string.") for entity ".$entity->stable_id);
          }
          my $ok_added2 = $entity->add_multiprop($new_concentration_prop);
          unless ($ok_added2) {
            $schema->defer_exception("Problem adding multiprop: (".$new_concentration_prop->as_string.") for entity ".$entity->stable_id);
          }
        } else {
          $schema->defer_exception_once("problem deleting insecticide conc multiprop");
        }
      } else {
        $schema->defer_exception_once("Nothing in IR lookup for concentration in units '$old_units_underscore_id'");
      }
      next;
    }

    #
    # regular processing: map all ontology terms, insert new multiprop and delete old one
    #
    my $mapped_something;
    my $retire_me;
    my @new_cvterms = map {
      my $old_term = $_;
      my $new_term = $old_term;
      # some terms don't need to be mapped because they are treated
      # specially during ISA-export
      unless ($do_not_map_terms->{$old_term->id}) {
        $new_term = main_map_old_term_to_new_term($old_term, $proptype, "process_entity_props() old multiprop term: '".$old_term->name."'");
        $mapped_something = 1 if ($new_term->id != $old_term->id);
      }
      if ($retire_me_terms->{$old_term->id}) {
        $retire_me = 1;
      }
      $new_term;
    } @orig_cvterms;
    if ($retire_me) {
      my $ok_deleted = $entity->delete_multiprop($multiprop);
      unless ($ok_deleted) {
        $schema->defer_exception("Problem retiring multiprop: (".$multiprop->as_string.") for entity ".$entity->stable_id);
      }
    } elsif ($mapped_something) {
      my $old_value = $multiprop->value;
      my $new_multiprop = Multiprop->new(cvterms=>\@new_cvterms, defined $old_value ? (value=>$old_value) : ());
      # warn "going to replace: ".$multiprop->as_string."\nwith:             ".$new_multiprop->as_string."\n";
      my $ok_deleted = $entity->delete_multiprop($multiprop);
      if ($ok_deleted) {
        my $ok_added = $entity->add_multiprop($new_multiprop);
        unless ($ok_added) {
          $schema->defer_exception("Problem adding multiprop: (".$new_multiprop->as_string.") for entity ".$entity->stable_id);
        }
      } else {
        $schema->defer_exception("Problem deleting multiprop: (".$multiprop->as_string.") for entity ".$entity->stable_id);
      }

    }

  }
}

#
# assay->type takes one of 5 forms: field collection, species ID, phenotype assay, genotype assay or sample manipulation
#
# just need to map the term (inplace updates $assays)
sub process_assay_type {
  my ($assay) = @_;
  my $old_type = $assay->type;
  my $new_type = main_map_old_term_to_new_term($old_type, 'NdExperiment', "Assay type");
  if ($new_type->id ne $old_type->id) {
    $assay->type($new_type);
    $assay->update;
  }
}

#
# in-place maps the assay protocol types
#
# does special things for collection protocols
#   - if 'process term ID for device term' column in main lookup is non-empty, use this for the protocol, and move the old term to a device prop.
#   - if 'attractant term ID' column in main lookup is non-empty, add an attractant prop to the assay
#
sub process_assay_protocols {
  my ($assay) = @_;
  my @new_protocol_terms;
  foreach my $protocol ($assay->protocols) {
    # don't do the same protocol more than once
    next if ($processed_protocol->{$protocol->id}++);
    my $old_type = $protocol->type;
    my $old_type_id = underscore_id($old_type->dbxref->as_string(), 'process_assay_protocols old_type to ID');

    my $lookup_row = $main_term_lookup->{$old_type_id}{'NdProtocol'};
    if ($lookup_row) {

      my $new_type = main_map_old_id_to_new_term($old_type_id, $old_type->name, 'NdProtocol', 'process_assay_protocols map old term to new');


      # the old protocol term may be a device!
      # so let's look up a possible process term and make some changes
      if ($lookup_row->{'process term ID for device term'}) {
        my $process_id = underscore_id($lookup_row->{'process term ID for device term'}, "process term lookup");
        my $process_term = get_cvterm($process_id, $lookup_row->{'process term for device term'});

        # set the protocol type to the process
        $protocol->type($process_term);
        $protocol->update;
        # add an assay prop for the device
        my $device_prop = Multiprop->new(cvterms=>[ $device_heading_term, $new_type ]);
        $assay->add_multiprop($device_prop);
      } else {
        # simply map the old protocol type to the new one
        $protocol->type($new_type);
        $protocol->update;
      }

      # handle addition of attractant term from main lookup sheet if needed
      if ($lookup_row->{'attractant term ID'}) {
        my $attractant_id = underscore_id($lookup_row->{'attractant term ID'}, "attractant term lookup");
        my $attractant_term = get_cvterm($attractant_id, $lookup_row->{'attractant term'});
        my $attractant_prop = Multiprop->new(cvterms=>[ $attractant_heading_term, $attractant_term ]);
        $assay->add_multiprop($attractant_prop);
      }
    } else {
      $schema->defer_exception_once("No row in main lookup for '".$old_type->name."' ($old_type_id) in process_assay_protocols");
    }
  }
}


#
# map old_term_id (underscore style) to new term object
#
sub main_map_old_id_to_new_term {
  my ($old_term_id, $old_term_name, $proptype, @debug_info) = @_;

  my $lookup_row = $main_term_lookup->{$old_term_id}{$proptype};
  if ($lookup_row) {
    my $new_term_id = underscore_id($lookup_row->{'OBO ID'}, "main lookup result for '$old_term_name' ($old_term_id) $proptype", @debug_info);
    if ($new_term_id ) {
      return get_cvterm($new_term_id, $lookup_row->{'OBO Label'} || $old_term_name);
    }
  } else {
    $schema->defer_exception_once("No lookup row for '$old_term_name' ($old_term_id) $proptype - @debug_info");
  }
  return make_placeholder_cvterm(undef, $old_term_name);
}

#
# map old term object to new term object
#
sub main_map_old_term_to_new_term {
  my ($old_term, $proptype, @debug_info) = @_;
  my $old_term_id = underscore_id($old_term->dbxref->as_string(), @debug_info);
  return $old_term_id ? main_map_old_id_to_new_term($old_term_id, $old_term->name, $proptype, @debug_info) :
    make_placeholder_cvterm(undef, $old_term->name);
}


#
# units audit routines:
#

#
# takes an array of objects: [ { characteristics_headingN => characteristics_object } ]
#
# and returns an object { characteristics_heading1 => [ 'minute', 'hour' ], characteristics_heading2 => [ 'mg/l', 'mg/ml' ] }
# that lists the different units used (if any)
#
sub summarise_units {
  my @characteristics = @_;
  my $result = {};  # {$characteristic_heading} => [ unit_names, ... ]

  my @char_keys = characteristic_keys(@characteristics);
  foreach my $characteristic (@char_keys) {
    ### the following would work if there wasn't a bug in JSON::Path where
    ### JSON keys ('$characteristic') with colons in them cause a problem
    # my $units_jpath = JSON::Path->new(qq|\$.[*].['$characteristic'].unit.value|);
    # my @units = uniq($units_jpath->values(\@characteristics));

    # instead, filter with Perl
    my @these_chars = grep { defined $_ } map { $_->{$characteristic} } @characteristics;
    my $units_jpath = JSON::Path->new(qq|\$.[*].unit.value|);
    my @units = uniq($units_jpath->values(\@these_chars));
    $result->{$characteristic} = \@units;
  }
  return $result;
}


#
# takes an arrayref of 'assay_chars' from above
# returns an array of characteristics keys (aka headings)
#
sub characteristic_keys {
  my @characteristics = @_;
  return uniq(map { keys %{$_} } @characteristics);
}


#
# creates a deferred exception if there are multiple units for any characteristics
#
sub warn_units {
  my ($unit_summary, $message, $schema) = @_;
  foreach my $characteristic (keys %$unit_summary) {
    if (scalar @{$unit_summary->{$characteristic}} > 1) {
      $schema->defer_exception_once(sprintf "MIXED UNITS in '%s':'%s' => (%s)",
                                    $message,
                                    $characteristic,
                                    join ',', map "'$_'", @{$unit_summary->{$characteristic}});
    }
  }
}
