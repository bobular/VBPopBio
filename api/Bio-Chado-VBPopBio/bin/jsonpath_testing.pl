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

# $JSON::Path::Safe = 0;  # needed for sub-expressions only foo[?(expr)]

my ($file) = @ARGV;
my $json_pretty = JSON->new->pretty;

my $text = read_file($file);
## seems to be a bug in JSON::Path (filter expression evaluation) where JSON keys with colon in them cause weird problems
# so we remove some EUPATH: and OBI: etc prefixes from Characteristics keys
# $text =~ s/[A-Z]+://g;
my $isatab = decode_json($text);

my $source_chars = JSON::Path->new('$.studies[0].sources[*].characteristics');
my @source_chars = $source_chars->values($isatab);
print "=== sources/collections ===\n";
my $source_units = summarise_units(@source_chars);
print $json_pretty->encode($source_units);

my $sample_chars = JSON::Path->new('$.studies[0].sources[*].samples[*].characteristics');
my @sample_chars = $sample_chars->values($isatab);
print "=== samples ===\n";
my $sample_units = summarise_units(@sample_chars);
print $json_pretty->encode($sample_units);


my $study_assay_measurement_types = JSON::Path->new('$.studies[0].study_assays[*].study_assay_measurement_type');
my @study_assay_measurement_types = $study_assay_measurement_types->values($isatab);

my $study_assays = JSON::Path->new('$.studies[0].study_assays');
my $assay_chars = JSON::Path->new('$.[*].samples[*].assays[*].characteristics');

my @study_assays = $study_assays->values($isatab);

foreach my $study_assay_measurement_type (uniq(@study_assay_measurement_types)) {
  # filter without using JSON::Path subexpressions, due to a colon-related bug in JSON::Path
  my @this_type_assays = grep { $_->{study_assay_measurement_type} eq $study_assay_measurement_type } @{$study_assays[0]};

  print "=== $study_assay_measurement_type ===\n";
  my @assay_chars = $assay_chars->values(\@this_type_assays);

  my $units_summary = summarise_units(@assay_chars);
  print $json_pretty->encode($units_summary);
}

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







