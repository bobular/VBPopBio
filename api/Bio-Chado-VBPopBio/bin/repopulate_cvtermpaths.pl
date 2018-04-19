#!/usr/bin/env perl
# -*- mode: cperl -*-
#
#
# usage: CHADO_DB_NAME=my_chado_instance bin/repopulate_cvtermpaths.pl [ --cv "xyz" --cv "abc" ]
#

use strict;
use warnings;
use Carp;
use lib 'lib';
use Bio::Chado::VBPopBio;
use JSON;
use Getopt::Long;

my @cvs = qw/insecticide_resistance_ontology /;
GetOptions("cv=s"=>\@cvs);

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });

#
# BASIC PLAN
#
# foreach $cv (given via name in args)
#   foreach $cvterm ($cv->cvterms->all)
#     $cvterm->populate_cvtermpath_parents_if_needed()
#
#

#
# STILL TO DO
#
#
# some of our ontologies (especially VBcv) are split over many different "namespaces"
#
# and that means their terms belong to many different "cv" entities in Chado, so this becomes a bit messy
#
