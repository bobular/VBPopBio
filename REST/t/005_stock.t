use Test::More tests => 20;
use strict;
use warnings;
use lib '../api/Bio-Chado-VBPopBio/lib';

# the order is important
use VBPopBioREST;
use Dancer::Test;

use JSON;

my $stock_id = 'VBS0000001';
my $verbose = 1; # print JSON responses to terminal
my ($url, $response, $json, $data);

#
# test stock/ID/head
#

$url = "/stock/$stock_id/head";
route_exists([ GET=>$url ], "$url route exists");
$response = dancer_response GET => $url;
$json = $response->{content};
diag("$url response:\n$json") if ($verbose); # print diagnostics to terminal
$data = eval { from_json $json };
ok($data, "$url json decoding");
is($data->{id}, $stock_id, "$url ID check");
is($data->{name}, "SM-NRUE", "$url name check");
is($data->{external_id}, "SM-NRUE", "$url external_id check");
ok(defined $data->{organism}, "$url stock has organism");

#
# test full stock/ID
#

$url = "/stock/$stock_id";
route_exists([ GET=>$url ], "$url route exists");
$response = dancer_response GET => $url;
$json = $response->{content};
diag("$url response:\n$json") if ($verbose); # print diagnostics to terminal
$data = eval { from_json $json };
ok($data, "$url json decoding");
is($data->{id}, $stock_id, "$url ID check");
is($data->{name}, "SM-NRUE", "$url name check");
is($data->{external_id}, "SM-NRUE", "$url external_id check");
ok(defined $data->{organism}, "$url stock has organism");
# see if it has one field_collection
is(ref($data->{field_collections}), "ARRAY", "$url field_collections array");
is(ref($data->{genotype_assays}), "ARRAY", "$url genotype_assays array");
is(ref($data->{phenotype_assays}), "ARRAY", "$url phenotype_assays array");
is(ref($data->{species_identification_assays}), "ARRAY", "$url species_identification_assays array");
is(scalar(@{$data->{field_collections}}), 1, "$url one field collection");
# these tests make sure that experiment subclasses have specialised as_data_structure
ok(!defined $data->{field_collections}->[0]->{warning}, "$url field_collections shouldn't contain warning");
ok(!defined $data->{species_identification_assays}->[0]->{warning}, "$url species_identification_assays shouldn't contain warning");
ok(!defined $data->{genotype_assays}->[0]->{warning}, "$url genotype_assays shouldn't contain warning");
#no phenotype assay for this sample, so can't test
#ok(!defined $data->{phenotype_assays}->[0]->{warning}, "$url phenotype_assays shouldn't contain warning");


