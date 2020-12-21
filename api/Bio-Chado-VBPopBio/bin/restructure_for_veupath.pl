#!/usr/bin/env perl
# -*- mode: cperl -*-
#
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

use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use Getopt::Long;
use utf8::all;
use Data::Dumper;

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

GetOptions("dry-run|dryrun"=>\$dry_run,
	   "projects=s"=>\$project_ids,
           "verbose"=>\$verbose,
           "limit=i"=>\$limit,
           "mapping_file|mapping_csv|mapping-file|mapping-csv=s"=>\$mapping_file,
           "ir_file|ir_csv|ir-attrs|ir-attrs-csv=s"=>\$ir_attr_file,
           "dump_isatab|dump-isatab"=>\$dump_isatab,
           "isatab_prefix|isatab-prefix=s"=>\$isatab_prefix,
	  );

die "can't --dump-isatab if --limit X is given\n" if ($dump_isatab && $limit);

die "need to give --projects PROJ_ID(s) and --mapping CSV_FILE params\n" unless (defined $project_ids && defined $mapping_file);

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
# constant ontology terms used below
#
my $ir_assay_base_term = $cvterms->find_by_accession({ term_source_ref => 'MIRO',
                                                       term_accession_number => '20000058' }) || die;

my $ir_biochem_assay_base_term = $cvterms->find_by_accession({ term_source_ref => 'MIRO',
							       term_accession_number => '20000003' }) || die;

my $new_insecticide_heading = main_map_old_id_to_new_term('MIRO_10000239', 'insecticidal substance', 'NdExperimentprop', 'new_insecticide_heading');


### some globals related to placeholder-making and other caches
my $vbcv = $schema->cvs->find({ name => 'VectorBase miscellaneous CV' });
my $vbdb = $schema->dbs->find({ name => 'VBcv' });
my $last_accession_number = 90000001;
my $processed_entity_props = {};


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
            process_assay_type($assay);

            # collection geolocation itself has props but we may want to remove these
            # and rely instead only on the terms we assign from lat/long lookup
            process_entity_props($assay->nd_geolocation, 'NdGeolocationprop');
          }

          my $species_assays = $sample->species_identification_assays;
          while (my $assay = $species_assays->next()) {
            # TO DO: map protocol old->new

            process_entity_props($assay, 'NdExperimentprop');
            process_assay_type($assay);
          }

          my $phenotype_assays = $sample->phenotype_assays;
          while (my $assay = $phenotype_assays->next()) {

            # process_assay_protocols($assay); # TO DO

            process_entity_props($assay, 'NdExperimentprop');
            process_assay_type($assay);

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
                          print "going to map from IR phenotype $attr_id '$new_value' $unit_id to characteristic $new_attr_id ($label) $new_unit_id ($new_unit_label)\n";
                          my $new_attr_term = get_cvterm($new_attr_id);
                          my $new_unit_term = get_cvterm($new_unit_id);
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
            } else {
              $schema->defer_exception("TO DO: process phenotype assays like ".$assay->stable_id);
            }
          }

          my $genotype_assays = $sample->genotype_assays;
          while (my $assay = $genotype_assays->next()) {
            # TO DO: map protocol old->new

            process_entity_props($assay, 'NdExperimentprop');
            process_assay_type($assay);
          }

          # TO DO: sample manipulations?? or at least, remove them


          $done_samples++;
          last if ($limit && $done_samples >= $limit);
	}

	$project->update_modification_date();

        if ($dump_isatab) {
          my $output_dir = $isatab_prefix.$project_id;
          my $isatab = $project->write_to_isatab({ directory=>$output_dir, protocols_first=>1 });
          warn "wrote $project_id ISA-Tab to $output_dir\n";
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
  my ($id) = @_;
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
  return make_placeholder_cvterm($id, "placeholder for $id");
}

#
# make placeholder term and return it
#
sub make_placeholder_cvterm {
  my ($name, $definition) = @_;
  my $pname = "Placeholder: $name";

  # first look up by name if already made
  my $already_made_term = $cvterms->find({ name => $pname,
                                           cv_id => $vbcv->id });
  if ($already_made_term) {
    return $already_made_term;
  }

  # otherwise make it
  # don't let these get committed to the database
  $schema->defer_exception_once("Making placeholder for '$name'");

  my $acc = $last_accession_number++;
  my $new_cvterm =
    $dbxrefs->find_or_create( { accession => $acc,
                                db => $vbdb },
                              { join => 'db' })->
                                find_or_create_related('cvterm',
                                                       { name => $pname,
                                                         definition => $definition || 'placeholder term',
                                                         cv => $vbcv
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
        my $new_concentration_term = get_cvterm($new_concentration_underscore_id);

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
    my @new_cvterms = map {
      my $old_term = $_;
      my $new_term = $old_term;
      # some terms don't need to be mapped because they are treated
      # specially during ISA-export
      unless ($do_not_map_terms->{$old_term->id}) {
        $new_term = main_map_old_term_to_new_term($old_term, $proptype, "process_entity_props() old multiprop term: '".$old_term->name."'");
        $mapped_something = 1 if ($new_term->id != $old_term->id);
      }
      $new_term;
    } @orig_cvterms;
    if ($mapped_something) {
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
# map old_term_id (underscore style) to new term object
#
sub main_map_old_id_to_new_term {
  my ($old_term_id, $old_term_name, $proptype, @debug_info) = @_;

  my $lookup_row = $main_term_lookup->{$old_term_id}{$proptype};
  if ($lookup_row) {
    my $new_term_id = underscore_id($lookup_row->{'OBO ID'}, "main lookup result for '$old_term_id'", @debug_info);
    if ($new_term_id ) {
      return get_cvterm($new_term_id);
    }
  } else {
    $schema->defer_exception_once("No lookup row for $old_term_id $proptype - @debug_info");
  }
  return make_placeholder_cvterm($old_term_name, "placeholder for $old_term_name ($old_term_id)");
}

#
# map old term object to new term object
#
sub main_map_old_term_to_new_term {
  my ($old_term, $proptype, @debug_info) = @_;
  my $old_term_id = underscore_id($old_term->dbxref->as_string(), @debug_info);
  return $old_term_id ? main_map_old_id_to_new_term($old_term_id, $old_term->name, $proptype, @debug_info) :
    make_placeholder_cvterm($old_term->name);
}
