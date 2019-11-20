#!/usr/bin/env perl
# -*- mode: cperl -*-
#
# prepares the necessary commands (and pre-creates the output directories) for export of ISA-Tab
# destined for VEuPathDB workflow loading
#
# run this in a production 'screen' from the usual production directory
#
# usage: bin/export_for_veupath.pl --projects VBPnnnnnnn,VBPmmmmmmm --output_dir isatab_dir | parallel --jobs .jobs
#
#
# options:
#   --projects ID1,ID2,ID3            : the project stable IDs to dump
#   --output_path_template xyz/%s/abc : e.g. PopBio/fromChado/%s/1/final
#

use strict;
use warnings;
use Carp;
use lib 'lib';
use Getopt::Long;
use utf8::all;
use POSIX 'strftime';
use File::Path qw(make_path);

my $project_ids;
my $output_path;

GetOptions("projects=s"=>\$project_ids,
	   "output_path_template|output-path-template=s"=>\$output_path,
	  );


die "must give --projects VBPnnnnnnn,VBPmmmmmmm arg\n" unless ($project_ids);
die "must give --output_path xyz/%s/abc arg\n" unless ($output_path);

my @project_ids = split /\W+/, $project_ids;

foreach my $project_id (@project_ids) {
  my $output_dir = sprintf $output_path, $project_id;
  if (make_path($output_dir) || -d $output_dir) {
    print <<"EOF";
bin/delete_project.pl --project $project_id --output $output_dir --dump_only
EOF
  } else {
    warn "COULD NOT CREATE OUTPUT DIRECTORY $output_dir from template $output_path and project_id $project_id\n";
  }
}

