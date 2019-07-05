#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: bin/project_fix_geo_qualifiers.pl --default-accuracy accurate --project VBP0000nnn
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
my $default_accuracy;
my $default_precision;
my $remove_precision;

# if this matches the comment type/heading
# e.g. Comment [collection site coordinates]
# then the comment will processed into ontology-based qualifiers
my $comment_regexp = qr/\bcollection site coordinates\b/;


GetOptions("dry-run|dryrun"=>\$dry_run,
	   "projects=s"=>\$project_ids,
           "limit=i"=>\$limit, # just process N collections per project, implies dry-run
           "default-accuracy=s"=>\$default_accuracy,
           "default-precision=i"=>\$default_precision,
           "remove-precision"=>\$remove_precision,
	  );


die "must provide options --default-accuracy and --project\n" unless ($default_accuracy && $project_ids);

$dry_run = 1 if ($limit);

$| = 1;


my $comment_term = $schema->types->comment;

# geolocation qualifier headings
my $geoloc_accuracy_term = $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001151' }) || die;
my $geoloc_precision_term = $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001140' }) || die;
my $geoloc_provenance_term = $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001139' }) || die;

# geolocation provenance values
my $ic_term = $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001141' }) || die;
my $ia_term = $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001142' }) || die;
my $ip_term = $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001143' }) || die;

# geolocation accuracy values
my $accurate_term = $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001152' }) || die;
my $inaccurate_term = $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001153' }) || die;
my %accuracy_terms = ( accurate => $accurate_term, inaccurate => $inaccurate_term);
die "default accuracy must be one of: ".join(", ", keys %accuracy_terms)."\n" unless ($accuracy_terms{$default_accuracy});


# geolocation precision values
my @geolocation_precision_terms =
  (
   $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001144' }), # 0 or better
   $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001145' }), # 1 or better
   $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001146' }),
   $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001147' }),
   $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001148' }),
   $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001149' }),
   $schema->cvterms->find_by_accession({ term_source_ref => 'VBcv', term_accession_number => '0001150' }), # 6 decimal places
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

	$project->update_modification_date() if ($project);

	foreach my $collection ($project->field_collections) {

          my @props = $collection->multiprops;
          my @RIP_props;
          my $collection_accuracy = $default_accuracy;

          foreach my $prop (@props) {
            my ($heading_term, @value_terms) = $prop->cvterms;

            # is it a comment term?
            if ($heading_term->id == $comment_term->id) {
              my $comment_text = $prop->value;
              my ($comment_heading, $comment) = $comment_text =~ /^\[(.+?)\]\s*(.+)$/;

              if ($comment_heading =~ $comment_regexp) {
                push @RIP_props, $prop;

                if ($comment eq 'IP') {
                  $collection->add_multiprop(Multiprop->new(cvterms=>[$geoloc_provenance_term, $ip_term]));
                } elsif ($comment eq 'IA') {
                  $collection->add_multiprop(Multiprop->new(cvterms=>[$geoloc_provenance_term, $ia_term]));
                } elsif ($comment eq 'IC') {
                  $collection->add_multiprop(Multiprop->new(cvterms=>[$geoloc_provenance_term, $ic_term]));
                  $collection_accuracy = 'inaccurate';
                } else {
                  my $collection_id = $collection->stable_id;
                  $schema->defer_exception("unknown comment value '$comment' for $collection_id");
                }

              }
            }

            if ($heading_term->id == $geoloc_accuracy_term->id) {
              push @RIP_props, $prop;
            }
            if ($heading_term->id == $geoloc_precision_term->id) {
              if (defined $default_precision) {
                push @RIP_props, $prop;
              } elsif (!$remove_precision) {
                my $collection_id = $collection->stable_id;
                $schema->defer_exception("previous geolocation precision prop found for $collection_id, but --default-precision not given on command line, therefore it will not be replaced.  Use --remove-precision option to force its removal.");
              }
            }

          }
          # remove the comment IC/IA/IP props and any old accuracy+precision props if needed
          map { $collection->delete_multiprop($_) } @RIP_props;

          # add the accuracy prop
          $collection->add_multiprop(Multiprop->new(cvterms=>[$geoloc_accuracy_term, $accuracy_terms{$collection_accuracy}]));

          # add the precision - if provided
          if (defined $default_precision) {
            $collection->add_multiprop(Multiprop->new(cvterms=>[$geoloc_precision_term, $geolocation_precision_terms[$default_precision]]));
          }

          printf "\rdone %4d of %4d collections", ++$done, $todo;
          last if ($limit && $done >= $limit);
	}
        print "\n";
      }
      $schema->defer_exception("dry-run option - rolling back") if ($dry_run);
    } );

