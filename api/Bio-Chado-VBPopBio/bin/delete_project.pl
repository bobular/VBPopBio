#!/usr/bin/env perl
# -*- mode: cperl -*-
#
# deletes a project, but only after dumping it to ISA-Tab files in 'output_dir'
#
#
#
# usage: CHADO_DB_NAME=my_chado_instance bin/delete_project.pl --project VBPnnnnnnn --dry-run --output_dir isatab_dir
#
# or with gnu parallel:
#
# sort project-ids-VB-2018-04.txt | parallel --jobs 8 --results ISA-Tab-test-dumps-post-merge bin/delete_project.pl --max 5000 --project {} --verify --ignore-geo-name --output ISA-Tab-test-dumps-post-merge/isa-tabs/{}
#
#
# options:
#   --dry-run              : rolls back transaction and doesn't delete from db permanently
#   --project              : the project stable ID to dump
#   --output_dir           : where to dump the ISA-Tab (defaults to PROJECTID-ISA-Tab-YYYY-MM-DD-HHMM)
#   --dump-only            : don't delete at all (much quicker)
#   --verify               : check that the dumped project can be reloaded losslessly
#                            (implies dry-run - so does not delete - use this for archiving)
#   --max_samples          : skip the whole process (no dump, no deletion) if more than this number of samples
#   --ignore-geo-name      : don't validate the contents of 'Collection site (VBcv:0000831)' column
#   --protocols-first      : in sample and assay sheets, output the Protocol REF before the Assay Name column
#                            for VEuPathDB compatibility!
#   --noprotocols-first    : disables the above which is now on by default

use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use JSON;
use Getopt::Long;
use utf8::all;
use POSIX 'strftime';
use Test::Deep::NoTest qw/cmp_details deep_diag ignore any set/;
use Data::Walk;
use Data::Dumper;

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $projects = $schema->projects;
my $dry_run;
my $json_file;
my $json = JSON->new->pretty;
my $project_id;
my ($verify, $ignore_geo_name);
my $output_dir;
my $max_samples;
my $dump_only;
my $protocols_first = 1;

GetOptions("dry-run|dryrun"=>\$dry_run,
	   "dump_only|dump-only"=>\$dump_only,
	   "json=s"=>\$json_file,
	   "project=s"=>\$project_id,
	   "output_dir|output-dir=s"=>\$output_dir,
	   "verify"=>\$verify,
	   "ignore-geo-name"=>\$ignore_geo_name,
	   "max_samples=i"=>\$max_samples,
           "protocols-first!"=>\$protocols_first,
	  );

$dry_run = 1 if ($verify);

my ($isatab_dir) = @ARGV;

die "must give --project VBPnnnnnnn arg\n" unless ($project_id);
die "can't combine --verify and --dump-only\n" if ($dump_only && $verify);

$output_dir //= sprintf "%s-ISA-Tab-%s", $project_id, strftime '%Y-%m-%d-%H%M', localtime;

# should speed things up
$schema->storage->_use_join_optimizer(0);

my $usage_license_term = $schema->types->usage_license;

$schema->txn_do_deferred
  ( sub {

      my $project = $projects->find_by_stable_id($project_id);
      die "can't find $project_id in database\n" unless ($project);

      my $num_samples = $project->stocks->count;
      if (defined $max_samples && $num_samples > $max_samples) {
	$schema->defer_exception("skipping this project as it has $num_samples samples (more than max_samples option)");
      } else {
        #
        # write presenter.xml for VEuPath deployment
        #
        my $project_name = $project->name;
        my $project_description = $project->description;
        $project_description =~ s/\s+$//; # remove any trailing whitespace
        # take first sentence
        my ($project_summary) = $project_description =~ m/^(.+?)(\.\s+[A-Z]|$)/s;
        my $primary_contact = $project->contacts->first;
        my $primary_contact_id = $primary_contact ? $primary_contact->name : "TODO"; # this is the email address actually

        my @tag_terms = $project->tags;
        my @licenses = map { $_->name } grep { $usage_license_term->has_child($_) } @tag_terms;

        my @publications = $project->publications;

	my $project_data = $project->as_data_structure;
	my $isatab = $project->write_to_isatab({ directory=>$output_dir, protocols_first=>$protocols_first });
	if (not $dump_only) {
          die "shouldn't do an actual delete in the epvb-export branch code";
	  $project->delete;
	  if ($verify) {
	    my $reloaded = $projects->create_from_isatab({ directory=>$output_dir });
	    my $reloaded_data = $reloaded->as_data_structure;
	    my ($result, $diagnostics) = cmp_details($reloaded_data, preprocess_data($project_data));
	    unless ($result) {
	      $schema->defer_exception("ERROR! Project reloaded from ISA-Tab has differences:\n".deep_diag($diagnostics));
	    }
	  }
	}
        #
        # write dataset.xml for GUS loader
        #
        open(DATASET, ">$output_dir/dataset.xml");
        print DATASET << "EOF";
  <dataset class="ISATabPopBio">
    <prop name="projectName">PopBio</prop>
    <prop name="studyType">fromChado</prop>
    <prop name="studyName">$project_id</prop>
    <prop name="version">1</prop>
  </dataset>

EOF
        close(DATASET);

        my $study_contacts = $isatab->{studies}[0]{study_contacts};
        my $primary_contact_name = join ' ', grep { $_ } ($study_contacts->[0]{study_person_first_name},
                                                          @{$study_contacts->[0]{study_person_mid_initials} // []},
                                                          $study_contacts->[0]{study_person_last_name});


        my @pubmed_ids = grep { $_ } map { $_->pubmed_id } @publications;
        my $pubmed_xml = join "\n    ", map { "<pubmedId>$_</pubmedId>" } @pubmed_ids;

        my $url_links_xml = join "\n    ", grep { $_ } map { if ($_->url) { sprintf "<link><text>%s</text><url>%s</url></link>", $_->title, $_->url; } } @publications;
        my $doi_links_xml = join "\n    ", grep { $_ } map { if ($_->doi) { sprintf "<link><text>DOI:%s</text><url>http://dx.doi.org/%s</url></link>", $_->doi, $_->doi; } } @publications;

        open(PRESENTER, ">$output_dir/presenter.xml");
        print PRESENTER << "EOF";
  <datasetPresenter name="ISATab_fromChado_${project_id}_RSRC"
                    projectName="PopBio"
                    >
    <displayName><![CDATA[$project_name]]></displayName>
    <shortDisplayName>$project_id</shortDisplayName>
    <shortAttribution>$study_contacts->[0]{study_person_last_name} et al.</shortAttribution>
    <summary><![CDATA[$project_summary]]></summary>
    <description><![CDATA[$project_description]]></description>
    <protocol></protocol>
    <caveat></caveat>
    <acknowledgement></acknowledgement>
    <releasePolicy>@licenses</releasePolicy>
    <primaryContactId>$primary_contact_id</primaryContactId>
    $url_links_xml
    $doi_links_xml
    $pubmed_xml
  </datasetPresenter>

EOF
        close(PRESENTER);

        open(CONTACT, ">$output_dir/contact.xml");
        print CONTACT << "EOF";
  <contact>
    <contactId>$primary_contact_id</contactId>
    <name>$primary_contact_name</name>
    <institution/>
    <email>$primary_contact_id</email>
    <address>$study_contacts->[0]{study_person_address}</address>
    <city/>
    <state/>
    <zip/>
    <country/>
  </contact>

EOF
        close(CONTACT);


      }

      $schema->defer_exception("--dry-run or --verify option used - rolling back") if ($dry_run);
    } );


#
# takes a nested data structure and descends into it looking for:
#
# 1. empty strings or undefs and making Test::Deep allow either
#
# 2. props (protocols and contacts) arrays and replacing them with set comparisons (ignore order)
#
# edits data IN PLACE - returns the reference passed to it
#
sub preprocess_data {
  my ($data) = @_;
  $data->{vis_configs} = ignore();
  $data->{last_modified_date} = ignore(); # because this will always be different!

  walk sub {
    my $node = shift;
    if (ref($node) eq 'HASH') {
      foreach my $key (keys %{$node}) {
	if (!defined $node->{$key} || $node->{$key} eq '') {
	  $node->{$key} = any(undef, '');
	} elsif ($key =~ /^(props|protocols|contacts)$/) {
	  $node->{$key} = set(@{$node->{$key}});
	} elsif ($key eq 'geolocation' && $ignore_geo_name) {
	  $node->{geolocation}{name} = ignore(); # because we dump the correct term names, but load the user-provided ones
	} elsif ($key eq 'uniquename') {
	  # ignore non-standard uniquenames
	  # added for a few projects
	  # by modify_genotypes_for_karyotype_summaries.pl
	  my $val = $node->{$key};
	  if ($val =~ s/:arrangement:/:/ ||
	      $val =~ s/:(\d)$/.$1/) {
	    $node->{$key} = $val;
	  }
	}
      }
    }
  }, $data;

  return $data;
}
