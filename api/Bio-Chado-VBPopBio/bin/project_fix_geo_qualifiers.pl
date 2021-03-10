#!/usr/bin/env perl
# -*- mode: cperl -*-
#
# This script loops over every collection object and looks to see if it has "Comment [collection site coordinates]" comments and
# will replace "IC" with "estimated by curator" and "IA" and "IP" with "provided" or "provided and obfuscated"
#
# If --curation-level option is provided (see below) then the appropriate child of "estimated by curator" will be used.
#
# If none of those comments are found - existing collection properties will not be changed.
#
# Options allow the replacement/addition/removal of geolocation precision terms
#
#
#
# usage: bin/project_fix_geo_qualifiers.pl --project VBP0000nnn
#
#        also allows comma-separated project IDs.
#
# recommend --dry-run so you can review what's going on
#
# options:
#
#   --default-precision 2  : number of decimal places of least-precise coordinates in project
#                            *note* if you don't provide this, nothing will be added.
#
#   --remove-precision     : remove any old precision annotations and don't complain if no new precision is provide (previous option)
#
#   --default-provenance IA : if no "collection site coordinates" comments containing IC/IA/IP are found, pretend this code was found instead
#
#
#   --obfuscated           : add the "provided and obfuscated" term for IA/IP
#
#   --curation-level {country,adm1,adm2,street} : use the corresponding child term of 'estimated by curator'
#
#   --dry-run              : rolls back transaction and doesn't insert into db permanently
#

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
my $samples = $schema->stocks;
my $cvterms = $schema->cvterms;
my $projects = $schema->projects;
my $dry_run;
my $project_ids;
my $limit;
my $default_precision;
my $default_provenance;
my $remove_precision;
my $obfuscated;
my $curation_level;

# if this matches the comment type/heading
# e.g. Comment [collection site coordinates]
# then the comment will processed into ontology-based qualifiers
my $comment_regexp = qr/\bcollection site coordinates\b/;


GetOptions("dry-run|dryrun"=>\$dry_run,
	   "projects=s"=>\$project_ids,
           "limit=i"=>\$limit, # just process N collections per project, implies dry-run
           "default-precision=i"=>\$default_precision,
           "remove-precision"=>\$remove_precision,
           "default-provenance=s"=>\$default_provenance,
           "obfuscated"=>\$obfuscated,
           "curation-level=s"=>\$curation_level,
	  );


die "must provide option --project\n" unless ($project_ids);
die "--default-provenance must be IA, IP or IC\n" if ($default_provenance && $default_provenance !~ /^(IC|IP|IA)$/);
$dry_run = 1 if ($limit);

$| = 1;


my $comment_term = $schema->types->comment;

# geolocation qualifier headings
my $geoloc_precision_term = $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001140' }) || die;
my $geoloc_provenance_term = $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001139' }) || die;

# geolocation provenance values
my $est_curator_term = $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001141' }) || die;

my %estimated_terms  = (
                        country => $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001156' }),
                        adm1 => $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001157' }),
                        adm2 => $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001158' }),
                        street => $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001159' }),
                       );

die "unrecognised curation-level '$curation_level'\n" if ($curation_level and not $estimated_terms{$curation_level});

my $provided_term = $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001143' }) || die;
my $obfuscated_term = $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001155' }) || die;


# geolocation precision values
my @geolocation_precision_terms =
  (
   $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001144' }), # 0 or better
   $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001145' }), # 1 or better
   $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001146' }),
   $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001147' }),
   $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001148' }),
   $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001149' }),
   $cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001150' }), # 6 decimal places
  );




$schema->txn_do_deferred
  ( sub {

      foreach my $project_id (split /\W+/, $project_ids) {
	my $project = $schema->projects->find_by_stable_id($project_id);
	unless ($project) {
	  $schema->defer_exception("project '$project_id' not found");
	  next;
	}
        my $done = 0;
        my $todo = $project->field_collections->count();
	warn "processing $project_id...\n";

        my %things_done; # "replaced IP with <term name>" => 1

	$project->update_modification_date() if ($project);

	foreach my $collection ($project->field_collections) {

          my @props = $collection->multiprops;
          my @RIP_props;

          my $found_a_comment;

          foreach my $prop (@props) {
            my ($heading_term, @value_terms) = $prop->cvterms;

            # is it a comment term?
            if ($heading_term->id == $comment_term->id) {
              my $comment_text = $prop->value;
              my ($comment_heading, $comment) = $comment_text =~ /^\[(.+?)\]\s*(.+)$/;

              if ($comment_heading =~ $comment_regexp) {
                push @RIP_props, $prop;

                if ($comment eq 'IP' || $comment eq 'IA') {
                  $collection->add_multiprop(my $p = Multiprop->new(cvterms=>[$geoloc_provenance_term,
                                                                              $obfuscated ? $obfuscated_term : $provided_term]));

                  $things_done{sprintf "replaced %s with %s", $comment, $p->as_string}++;
                  $found_a_comment = 1;
                } elsif ($comment eq 'IC') {
                  $collection->add_multiprop(my $p = Multiprop->new(cvterms=>[$geoloc_provenance_term,
                                                                              $curation_level ? $estimated_terms{$curation_level} :
                                                                              $est_curator_term]));
                  $things_done{sprintf "replaced %s with %s", $comment, $p->as_string}++;
                  $found_a_comment = 1;
                } else {
                  my $collection_id = $collection->stable_id;
                  $schema->defer_exception("unknown comment value '$comment' for $collection_id");
                }

              }
            }

            if ($heading_term->id == $geoloc_precision_term->id) {
              if (defined $default_precision || $remove_precision) {
                push @RIP_props, $prop;
              } elsif (!$remove_precision) {
                my $collection_id = $collection->stable_id;
                $schema->defer_exception("previous geolocation precision prop found for $collection_id, but --default-precision not given on command line, therefore it will not be replaced.  Use --remove-precision option to force its removal.");
              }
            }

          }

          # add the default_provenance if no "comment [collection site coordinates]" was found
          if (!$found_a_comment && $default_provenance) {
            if ($default_provenance eq 'IP' || $default_provenance eq 'IA') {
              $collection->add_multiprop(my $p = Multiprop->new(cvterms=>[$geoloc_provenance_term,
                                                                          $obfuscated ? $obfuscated_term : $provided_term]));
              $things_done{sprintf "default provenance added: %s", $p->as_string}++;
            } elsif ($default_provenance eq 'IC') {
              $collection->add_multiprop(my $p = Multiprop->new(cvterms=>[$geoloc_provenance_term,
                                                                          $curation_level ? $estimated_terms{$curation_level} :
                                                                          $est_curator_term]));
              $things_done{sprintf "default provenance added: %s", $p->as_string}++;
            }
          }


          # remove the comment IC/IA/IP props and any old precision props if needed
          map { $collection->delete_multiprop($_) } @RIP_props;

          # add the precision - if provided
          if (defined $default_precision) {
            $collection->add_multiprop(Multiprop->new(cvterms=>[$geoloc_precision_term, $geolocation_precision_terms[$default_precision]]));
            $things_done{"added precision level $default_precision"}++;
          }

          printf "\rdone %4d of %4d collections", ++$done, $todo;
          last if ($limit && $done >= $limit);
	}
        print "\n";

        foreach my $thing_done (sort keys %things_done) {
          print "'$thing_done' $things_done{$thing_done} times\n";
        }

      }
      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );

