use Test::More tests => 2;
use strict;
use warnings;
use lib '/home/ttiirikk/vbpopbio/api/Bio-Chado-VBPopBio/lib';

# the order is important
use VBPopBioREST;
use Dancer::Test;

use JSON;

route_exists([ GET=>'/project/VBP0000001/head' ], "/project/VBP0000001/head exists");
my $response = dancer_response GET => '/project/VBP0000001/head';

my $data = from_json $response->{content};
is($data->{id}, "VBP0000001", "got the ID back");

