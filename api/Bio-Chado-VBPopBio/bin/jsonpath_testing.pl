#!/usr/bin/env perl
# -*- mode: cperl -*-
#

use strict;
use warnings;
use File::Slurp;
use JSON::Path;
use JSON;
use List::MoreUtils qw(uniq);

$JSON::Path::Safe = 0;

my ($file) = @ARGV;
my $json_pretty = JSON->new->pretty;

my $text = read_file($file);
## seems to be a bug in JSON::Path (filter expression evaluation) where JSON keys with colon in them cause weird problems
# so we remove some EUPATH: and OBI: etc prefixes from Characteristics keys
$text =~ s/[A-Z]+://g;
my $isatab = decode_json($text);

my $source_chars = JSON::Path->new('$.studies[0].sources[*].characteristics');
#my @source_chars = $source_chars->values($isatab);
#print $json_pretty->encode(\@source_chars);

my $sample_chars = JSON::Path->new('$.studies[0].sources[*].samples[*].characteristics');
#my @sample_chars = $sample_chars->values($isatab);
#print $json_pretty->encode(\@sample_chars);

my $study_assays = JSON::Path->new('$.studies[0].study_assays[*]');
my @study_assays = $study_assays->values($isatab);

my $assay_chars = JSON::Path->new('$.samples[*].assays[*].characteristics');

foreach my $study_assay (@study_assays) {
  print "=== $study_assay->{study_assay_file_name} ===\n";
  my @assay_chars = $assay_chars->values($study_assay);
  my @char_keys = characteristic_keys(\@assay_chars);
  foreach my $characteristic (@char_keys) {
    print "== $characteristic ==\n";
    my $units_jpath = JSON::Path->new(qq|\$.samples[*].assays[*].characteristics['$characteristic'].unit.value|);
    my @units = uniq($units_jpath->values($study_assay));
    print "@units\n";
  }
}



#
# takes an arrayref of 'assay_chars' from above
# returns an array of characteristics keys (aka headings)
sub characteristic_keys {
  my ($chars) = @_;
  my %keys;
  return uniq(map { keys %{$_} } @$chars);
}







