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
my $dry_run = 1;  # while in development
my $project_ids;
my $verbose;
my $limit;
my $mapping_file = 'popbio-term-usage-VB-2019-08-master.csv';
my $ir_attr_file = 'popbio-term-usage-VB-2019-08-insecticide-attrs.csv';

GetOptions("dry-run|dryrun"=>\$dry_run,
	   "projects=s"=>\$project_ids,
           "verbose"=>\$verbose,
           "limit=i"=>\$limit,
           "mapping_file|mapping_csv|mapping-file|mapping-csv=s"=>\$mapping_file,
           "ir_file|ir_csv|ir-attrs|ir-attrs-csv=s"=>\$ir_attr_file,
	  );

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
  my $underscore_id = underscore_id($colon_id);
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
  my $attr_id = underscore_id($row->{'Term accession'});
  my $unit_id = underscore_id($row->{'Units ID'});
  die "problem with IR attr lookup file" unless ($attr_id && $unit_id);
  $ir_attr_lookup->{$attr_id}{$unit_id} = $row;
}




###
# constant ontology terms used below
#
my $ir_assay_base_term = $cvterms->find_by_accession({ term_source_ref => 'MIRO',
                                                       term_accession_number => '20000058' }) || die;

my $ir_biochem_assay_base_term = $cvterms->find_by_accession({ term_source_ref => 'MIRO',
							       term_accession_number => '20000003' }) || die;

my $placeholder_term = $schema->types->placeholder;

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

            # process_assay_protocols($assay); # TO DO

            process_assay_props($assay);

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
                my $attr_id = underscore_id($data->{attribute}{accession});
                my $unit_id = underscore_id($data->{value}{unit}{accession});
                my $new_value = clean_value($data->{value}{text});
                unless ($attr_id && $unit_id && length($new_value)) {
                  $schema->defer_exception("Phenotype for ".$assay->stable_id." missing one or more of required attribute, value and unit");
                  next;
                }
                # look up old->new mapping
                if (my $lookup_row = $ir_attr_lookup->{$attr_id}{$unit_id}) {
                  # is there a new ontology ID
                  if ($lookup_row->{'OBO ID'}) {
                    my $new_attr_id = underscore_id($lookup_row->{'OBO ID'});
                    if ($new_attr_id) {
                      my $label = $lookup_row->{'OBO Label'};
                      my $unit_lookup_row = $main_term_lookup->{$unit_id}{$object_type};
                      if ($unit_lookup_row) {
                        my $new_unit_id = underscore_id($unit_lookup_row->{'OBO ID'});
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
                        $schema->defer_exception_once("No row in main lookup for '$unit_id' '$object_type'");
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

sub underscore_id {
  my ($id) = @_;
  # already underscored and looks like an onto id?
  if ($id =~ /^\w+?_\w+$/) {
    return $id;
  } elsif ($id =~ /^\w+?:(\w+?_\w+)$/) { # already underscored AND colon prefixed - just return the latter bit
    return $1;
  } elsif ($id =~ /^\w+?:\w+$/) { # regular ONTO:0012345 style
    $id =~ s/:/_/;
    return $id;
  } else {
    $schema->defer_exception_once("Badly formed ontology ID given to underscore_id('$id') - likely from a lookup sheet");
  }
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
    } else {
      $schema->defer_exception_once("Term '$id' not in database");
    }
  } else {
    $schema->defer_exception_once("get_cvterm('$id') was provided with a poorly formed term ID");
  }
  return $placeholder_term;
}

#
# process props (aka characteristics) from all assays
# and perform specialised transformations where necessary (e.g. insecticide concentrations)
#
# works inplace/destructively on assay's multiprops
#

sub process_assay_props {
  my ($assay) = @_;

  my @multiprops = $assay->multiprops;

  foreach my $multiprop (@multiprops) {
    #
    # regular processing: map all ontology terms, insert new multiprop and delete old one
    #
    my $mapped_something;
    my @new_cvterms = map {
      my $old_term = $_;
      my $new_term = $placeholder_term;
      my $old_term_id = underscore_id($old_term->dbxref->as_string());
      my $lookup_row = $main_term_lookup->{$old_term_id}{'NdExperimentprop'};
      if ($lookup_row) {
        my $new_term_id = underscore_id($lookup_row->{'OBO ID'});
        $new_term = get_cvterm($new_term_id);
      } else {
        $schema->defer_exception_once("No lookup row for $old_term_id NdExperimentprop");
      }
      $mapped_something = 1 if ($new_term->id != $old_term->id);
      $new_term;
    } $multiprop->cvterms;
    if ($mapped_something) {
      my $old_value = $multiprop->value;
      my $new_multiprop = Multiprop->new(cvterms=>\@new_cvterms, defined $old_value ? (value=>$old_value) : ());
      warn "going to replace: ".$multiprop->as_string."\nwith:             ".$new_multiprop->as_string."\n";
    }

  }


}
