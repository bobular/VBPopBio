use Test::More tests => 2;
use strict;
use warnings;
use lib '/home/ttiirikk/vbpopbio/api/Bio-Chado-VBPopBio/lib';

# the order is important
use VBPopBioREST;
use Dancer::Test;

use JSON;

route_exists([ GET=>'/project/VBP0000001' ], "/project/VBP0000001 exists");
my $response = dancer_response GET => '/project/VBP0000001';

my $data = from_json $response->{content};
is($data->{id}, "VBP0000001", "got the ID back");

