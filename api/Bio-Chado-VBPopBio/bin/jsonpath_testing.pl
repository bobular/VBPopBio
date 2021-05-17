#!/usr/bin/env perl
# -*- mode: cperl -*-
#
# REQUIRES Perl >= 5.16
#

use 5.016;
use strict;
use warnings;
use File::Slurp;
use JSON::Path;
use JSON;
use List::MoreUtils qw(uniq);

$JSON::Path::Safe = 0;  # needed for sub-expressions only foo[?(expr)]

my ($file) = @ARGV;
my $json_pretty = JSON->new->pretty;

my $text = read_file($file);
## seems to be a bug in JSON::Path (filter expression evaluation) where JSON keys with colon in them cause weird problems
# so we remove some EUPATH: and OBI: etc prefixes from Characteristics keys
$text =~ s/[A-Z]+://g;
my $isatab = decode_json($text);

my $source_chars = JSON::Path->new('$.studies[0].sources[*].characteristics');
my @source_chars = $source_chars->values($isatab);
#print $json_pretty->encode(\@source_chars);


my $sample_chars = JSON::Path->new('$.studies[0].sources[*].samples[*].characteristics');
my @sample_chars = $sample_chars->values($isatab);
#print $json_pretty->encode(\@sample_chars);


my $study_assay_measurement_types = JSON::Path->new('$.studies[0].study_assays[*].study_assay_measurement_type');
my @study_assay_measurement_types = $study_assay_measurement_types->values($isatab);
#print $json_pretty->encode(\@study_assay_measurement_types);

foreach my $study_assay_measurement_type (uniq(@study_assay_measurement_types)) {

  my $assay_chars_by_type = JSON::Path->new(qq|\$.studies[0].study_assays[?(\$_->{study_assay_measurement_type} eq '$study_assay_measurement_type')].samples[*].assays[*].characteristics|);

  my @assay_chars = $assay_chars_by_type->values($isatab);
  print "=== $study_assay_measurement_type ===\n";
  print $json_pretty->encode(\@assay_chars);
}


#  print "=== $study_assay->{study_assay_file_name} ===\n";
#  my @assay_chars = $assay_chars->values($study_assay);
#
#  # $units_audit->{$characteristic_heading} => [ unit_names, ... ]
#  my $units_audit = audit_characteristics_units(@assay_chars);


sub summarise_characteristics_units {
  my @characteristics = @_;
  my $result = {};  # {$characteristic_heading} => [ unit_names, ... ]

  my @char_keys = characteristic_keys(\@characteristics);
  foreach my $characteristic (@char_keys) {
    my $units_jpath = JSON::Path->new(qq|\$.samples[*].assays[*].characteristics['$characteristic'].unit.value|);
#    my @units = uniq($units_jpath->values($study_assay));
#    $result->{$characteristic} = \@units;
  }
  return $result;
}


#
# takes an arrayref of 'assay_chars' from above
# returns an array of characteristics keys (aka headings)
#
sub characteristic_keys {
  my $characteristics = @_;
  return uniq(map { keys %{$_} } @$characteristics);
}







