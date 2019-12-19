#!/usr/bin/env perl
# -*- mode: cperl -*-
#
# similar to global_term_usage_report.pl but gives more details on the types of assays the terms are attached to
#
#
#
# usage: CHADO_DB_NAME=my_chado_instance bin/global_protocol_usage_report.pl > protocol_usage.tsv
#
#
#


use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use JSON;
use Getopt::Long;


GetOptions();

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $cvterms = $schema->cvterms;



my $search = $schema->assays->search({}, { join => { 'nd_experiment_protocols' => 'nd_protocol' },
                                           columns => { 'me.type_id' => 'me.type_id',
                                                        'nd_experiment_protocols.nd_protocol.type_id' => 'nd_protocol.type_id' },
                                           select => [ { count => 'nd_protocol.type_id' } ],
                                           as => [ 'count' ],
                                           group_by => [ 'me.type_id', 'nd_protocol.type_id' ],
                                         });


print join("\t", "Assay_class", "Protocol_name", "Protocol_id", "Usage_count")."\n";

while (my $row = $search->next) {
  my $assay_type = $row->type;
  my $count = $row->get_column('count');
  foreach my $linker ($row->nd_experiment_protocols) {
    my $protocol_type = $linker->nd_protocol->type;
    print join("\t", $assay_type->name,
               $protocol_type->name, $protocol_type->dbxref->as_string, $count)."\n";
  }
}

