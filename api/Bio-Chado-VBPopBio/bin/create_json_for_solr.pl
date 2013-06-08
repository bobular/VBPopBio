#!/usr/bin/env perl
#                 -*- mode: cperl -*-
#
# usage: bin/create_json_for_solr.pl -dbname vb_popgen_testing_20110607 > test-samples.json
#
## get example solr server running (if not already)
# cd /home/maccallr/vectorbase/popgen/search/apache-solr-3.5.0/example/
# screen -S solr-popgen java -jar start.jar
#
## add data like this:
# curl 'http://localhost:8983/solr/update/json?commit=true' --data-binary @test-samples.json -H 'Content-type:application/json'
#
#


use strict;
use warnings;
use feature 'switch';
use lib 'lib';  # this is so that I don't have to keep installing BCNA for testing
use Getopt::Long;
use Bio::Chado::VBPopBio;
use Config::General;
use JSON; # for debugging only


my $dbname = $ENV{CHADO_DB_NAME};
my $dbuser = $ENV{USER};
my $dry_run;

GetOptions("dbname=s"=>\$dbname,
	   "dbuser=s"=>\$dbuser,
	   "dry-run|dryrun"=>\$dry_run,
	  );

#my ($input_file) = @ARGV;
#my $conf = new Config::General(-ConfigFile => $input_file,
#			       -SplitPolicy => 'equalsign',
#			      );
my %config = (); # $conf->getall;

$dbuser = $config{dbuser} || $dbuser;
$dbname = $config{dbname} || $dbname;

my $dsn = "dbi:Pg:dbname=$dbname";
my $schema = Bio::Chado::VBPopBio->connect($dsn, $dbuser, undef, { AutoCommit => 1 });
my $stocks = $schema->stocks; # ->search({}, {order_by=>'stock_id'})->slice(300,330);
my $projects = $schema->projects;
my $cvterms = $schema->cvterms;
my $json = JSON->new->pretty; # useful for debugging

my $done = 0;
print "{\n";
while (my $stock = $stocks->next) {

  my $solr_id = "stock_".$stock->id;
  print qq!"delete": { "id": "$solr_id" },\n!;

  my $stock_type = $stock->type->name;

  my $document = { doc =>
		   {
		    name => $stock->name,
		    id => $solr_id,
		    type => 'sample',
		    description => $stock->description ? $stock->description : $stock_type,

        geolocations => [ summarise_geolocations($stock) ],
				genotypes => [ summarise_genotypes($stock) ],
				phenotypes => [ summarise_phenotypes($stock) ],
				species => [ summarise_species($stock) ],
		   }
		 };
  my $json = $json->encode($document);
  chomp($json);
  print qq!"add": $json,\n!;

#  last if (++$done == 20);
}

while (my $project = $projects->next) {

  my $solr_id = "project_".$project->id;
  print qq!"delete": { "id": "$solr_id" },\n!;

  my $document = { doc =>
		   {
		    name => $project->name,
		    id => $solr_id,
		    type => 'project',
		    description => $project->description ? $project->description : '',
		   }
		 };
  my $json = $json->encode($document);
  chomp($json);
  print qq!"add": $json,\n!;

#  last if (++$done == 20);
}

print qq!"optimize": {}\n!;
print "}\n";

#
# WARNING:
# much ported/copied from frontend.js summariseExperiments !!
#
# returns an array of strings (one per geolocation)
#
sub summarise_geolocations {
	my $stock = shift;
	my @result = ();
	foreach my $experiment ($stock->field_collections) {
		my %strings;
		my $geo = $experiment->nd_geolocation;
	  map { $strings{$_->type->name}++ } grep { $_->type->cv->name eq 'GAZ' } $geo->nd_geolocationprops;
		if ($geo->description) {
			$strings{$geo->description}++;
		}
		if ($geo->longitude || $geo->latitude) {
			$strings{'WGS 84: '.$geo->latitude.','.$geo->longitude}++;
		}
		# handle VBcv:collection site XXXX
		map { $strings{$_->value}++  } grep { $_->type->cv->name eq 'VBcv' && $_->type->name =~ /^collection site/i } $geo->nd_geolocationprops;

		push @result, join '; ', keys %strings if (keys %strings);
	}

	return @result;
}

sub summarise_genotypes {
	my $stock = shift;
	my @result = ();
	foreach my $experiment ($stock->genotype_assays) {
		push @result, map { $_->uniquename } $experiment->genotypes;
	}

	return @result;
}

sub summarise_phenotypes {
	my $stock = shift;
	my @result = ();
	foreach my $experiment ($stock->phenotype_assays) {
		push @result, map { join "; ", (map { grep { defined && /\w/ } $_->type->name, $_->value } $experiment->nd_experimentprops->search({}, {order_by=>'rank'})), grep { defined }
													( $_->observable && $_->observable->name,
														$_->attr && $_->attr->name,
															$_->cvalue && $_->cvalue->name,
																$_->value ) } $experiment->phenotypes;
	}

	return @result;
}

sub summarise_species {
	my $stock = shift;
	my @result = ();

	# priority is sp id assays
	foreach my $experiment ($stock->species_identification_assays) {
		push @result, map { $_->type->name } $experiment->nd_experimentprops;
	}

	# fallback is stock->organism
	if (@result == 0) {
		push @result, $stock->organism ? $stock->organism->genus.' '.$stock->organism->species : ();
	}

	return @result;
}
