#!/usr/bin/env perl
#                 -*- mode: cperl -*-
#
# How to run
# psql --list to get the latest version of vb-popbio
# export CHADO_DB_NAME=popbio-v4.1.1-VB-2015-08-prod-01
# usage: bin/create_json_for_solr.pl -dbname vb_popgen_testing_20110607 > test-samples.json
#
#
#
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
use lib 'lib';
use Getopt::Long;
use Bio::Chado::VBPopBio;
use JSON;
use DateTime::Format::ISO8601;
use DateTime;
use Geohash;

my $dbname = $ENV{CHADO_DB_NAME};
my $dbuser = $ENV{USER};
my $dry_run;
my $limit;
my $project_stable_id;

GetOptions(
    "dbname=s"       => \$dbname,
    "dbuser=s"       => \$dbuser,
    "dry-run|dryrun" => \$dry_run,
    "limit=i"        => \$limit,                # for debugging/development
    "project=s"      => \$project_stable_id,    # just one project for debugging
);

my $dsn = "dbi:Pg:dbname=$dbname";
my $schema =
  Bio::Chado::VBPopBio->connect( $dsn, $dbuser, undef, { AutoCommit => 1 } );

# the next line is for extra speed - but check for identical results with/without
$schema->storage->_use_join_optimizer(0);
my $stocks   = $schema->stocks;
my $projects = $schema->projects;
my $assays   = $schema->assays;

my $json = JSON->new->pretty;    # useful for debugging
my $gh   = Geohash->new();
my $done;

# stops "wide character in print" warnings
binmode( STDOUT, ":utf8" );

#
# debug only
#
if ($project_stable_id) {
    my $project = $projects->find_by_stable_id($project_stable_id);
    $stocks = $project->stocks;
    $assays = $project->experiments;
}

# 'bioassay' MIRO:20000058
# because unfortunately we have used MIRO:20000100 (PCR amplification of specific alleles)
# to describe genotype assays totally unrelated to insecticide resistance
my $ir_assay_base_term = $schema->cvterms->find_by_accession(
    {
        term_source_ref       => 'MIRO',
        term_accession_number => '20000058'
    }
);

# insecticidal substance
my $insecticidal_substance = $schema->cvterms->find_by_accession(
    {
        term_source_ref       => 'MIRO',
        term_accession_number => '10000239'
    }
);
 
# quantitative qualifier
my $quantitative_qualifier = $schema->cvterms->find_by_accession(
    {
        term_source_ref       => 'VBcv',
        term_accession_number => '0000702'
    }
);

my $concentration_term = $schema->cvterms->find_by_accession(
    {
        term_source_ref       => 'PATO',
        term_accession_number => '0000033'
    }
);

my $duration_term = $schema->cvterms->find_by_accession(
    {
        term_source_ref       => 'EFO',
        term_accession_number => '0000433'
    }
);

my $sample_size_term = $schema->cvterms->find_by_accession(
    {
        term_source_ref       => 'VBcv',
        term_accession_number => '0000983'
    }
);

my $iso8601 = DateTime::Format::ISO8601->new;

my $start_date_type = $schema->types->start_date;
my $date_type       = $schema->types->date;

print "{\n";

### SAMPLES ###
$done = 0;
while ( my $stock = $stocks->next ) {
    my $stable_id = $stock->stable_id;
    die "stock with db id " . $stock->id . " does not have a stable id"
      unless ($stable_id);

    my $latlong = stock_latlong($stock);    # only returns coords if one site
    my $stock_best_species = $stock->best_species();

    # Only process samples with geodata or valid species
    next unless ( $latlong && $stock_best_species );

    my $date = stock_date($stock);
    my @collection_protocol_types =
      map { $_->type } map { $_->protocols->all } $stock->field_collections;
    my $fc                = $stock->field_collections->first;
    my @field_collections = $stock->field_collections;
    my @phenotype_assays  = $stock->phenotype_assays;
    my @phenotypes        = map { $_->phenotypes->all } @phenotype_assays;

    # my @genotype_assays   = $stock->genotype_assays;
    # my @genotypes         = map { $_->genotypes->all } @genotype_assays;

# We need several documents for each sample, one for every autocomplete entity (e.g. Taxon, Projects, pubmedid, paper titles)

    # first for taxons
    my @taxons;
    my $json_text;

    # ($stock_best_species)
    # ? ( @taxons = flattened_parents($stock_best_species) )
    # : ( push @taxons, "Unknown" );

    @taxons = flattened_parents($stock_best_species);

    my $i = 0;
    foreach my $taxon (@taxons) {

        # Taxonomy
        my $documentTaxons = {
            doc => {
                id         => $stable_id . "_taxon_" . $i,
                stable_id  => $stable_id,
                type       => 'Taxonomy',
                bundle     => 'pop_sample',
                date       => $date,
                geo_coords => $latlong,
                ( $i == 0 )
                ? (
                    textboost => 100,
                    field     => 'species'
                  )
                : (
                    textboost => 20,
                    field     => 'species_cvterms'
                ),
                textsuggest => $taxon,
            }
        };

        $json_text = $json->encode($documentTaxons);
        chomp($json_text);
        print qq!"add": $json_text,\n!;
        $i++;
    }

    # Description
    my $documentDescription = {
        doc => {
            id          => $stable_id . "_desc",
            stable_id   => $stable_id,
            type        => 'Description',
            field       => 'description',
            bundle      => 'pop_sample',
            geo_coords  => $latlong,
            date        => $date,
            textsuggest => $stock->description || join( ' ',
                ( $stock_best_species ? $stock_best_species->name : () ),
                $stock->type->name,
                ( $fc ? $fc->geolocation->summary : () ) ),
        }
    };

    $json_text = $json->encode($documentDescription);
    chomp($json_text);
    print qq!"add": $json_text,\n!;

    # Title
    my $documentTitle = {
        doc => {
            id          => $stable_id . "_title",
            stable_id   => $stable_id,
            type        => 'Title',
            field       => 'label',
            bundle      => 'pop_sample',
            geo_coords  => $latlong,
            date        => $date,
            textsuggest => $stock->name,

        }
    };

    $json_text = $json->encode($documentTitle);
    chomp($json_text);
    print qq!"add": $json_text,\n!;

    # Stable ID
    my $documentID = {
        doc => {
            id          => $stable_id . "_stable_id",
            stable_id   => $stable_id,
            type        => 'Stable ID',
            field       => 'id',
            bundle      => 'pop_sample',
            geo_coords  => $latlong,
            date        => $date,
            textsuggest => $stable_id,

        }
    };

    $json_text = $json->encode($documentID);
    chomp($json_text);
    print qq!"add": $json_text,\n!;

    # Pubmed ID(s)
    my @pubs = multiprops_pubmed_ids($stock);
    $i = 0;
    foreach my $pub (@pubs) {
        my $documentPubmedIDs = {
            doc => {
                id          => $stable_id . "_pmid_" . $i,
                stable_id   => $stable_id,
                bundle      => 'pop_sample',
                type        => 'Pubmed references',
                field       => 'pubmed',
                geo_coords  => $latlong,
                date        => $date,
                textsuggest => "PMID:" . $pub,
            }
        };
        $json_text = $json->encode($documentPubmedIDs);
        chomp($json_text);
        print qq!"add": $json_text,\n!;
        $i++;
    }

    # Project(s)
    my @projects = $stock->projects;
    $i = 0;
    foreach my $project (@projects) {
        my $documentProjects = {
            doc => {
                id          => $stable_id . "_proj_" . $i,
                stable_id   => $stable_id,
                bundle      => 'pop_sample',
                type        => 'Projects',
                geo_coords  => $latlong,
                date        => $date,
                textsuggest => quick_project_stable_id($project),
                field       => 'projects',
            }
        };

        $json_text = $json->encode($documentProjects);
        chomp($json_text);
        print qq!"add": $json_text,\n!;
        $i++;
    }

    # Sample type
    my $documentSampleType = {
        doc => {
            id          => $stable_id . "_sample_type",
            stable_id   => $stable_id,
            type        => 'Sample type',
            field       => 'sample_type',
            bundle      => 'pop_sample',
            geo_coords  => $latlong,
            date        => $date,
            textsuggest => $stock->type->name,

        }
    };

    $json_text = $json->encode($documentSampleType);
    chomp($json_text);
    print qq!"add": $json_text,\n!;

    # Geolocations
    my @geolocations = remove_gaz_crap(
        map { flattened_parents($_) }
          map { multiprops_cvterms( $_->geolocation, qr/^GAZ:\d+$/ ) }
          @field_collections
    );

    $i = 0;
    foreach my $geolocation (@geolocations) {

        my $documentGeolocations = {
            doc => {
                id         => $stable_id . "_geolocation_" . $i,
                stable_id  => $stable_id,
                type       => 'Geography',
                bundle     => 'pop_sample',
                date       => $date,
                geo_coords => $latlong,
                ( $i == 0 )
                ? (
                    textboost => 100,
                    field     => 'geolocations_cvterms'
                  )
                : (
                    textboost => 30,
                    field     => 'geolocations_cvterms'
                ),
                textsuggest => $geolocation,
            }
        };

        $json_text = $json->encode($documentGeolocations);
        chomp($json_text);
        print qq!"add": $json_text,\n!;
        $i++;
    }

    # Collection protocols

    my @collectionProtocols =
      map { flattened_parents($_) } @collection_protocol_types;
    $i = 0;
    foreach my $protocol (@collectionProtocols) {

        my $documentColProtocol = {
            doc => {
                id         => $stable_id . "_colProtocol_" . $i,
                stable_id  => $stable_id,
                bundle     => 'pop_sample',
                type       => 'Collection protocols',
                geo_coords => $latlong,
                date       => $date,
                ( $i == 0 )
                ? (
                    textboost => 100,
                    field     => 'collection_protocols_cvterms'
                  )
                : (
                    textboost => 20,
                    field     => 'collection_protocols_cvterms'
                ),
                textsuggest => $protocol,
            }
        };

        $json_text = $json->encode($documentColProtocol);
        chomp($json_text);
        print qq!"add": $json_text,\n!;
        $i++;
    }

#########################################################

    # now handle phenotypes

    foreach my $phenotype_assay (@phenotype_assays) {

        # is it a phenotype that we can use?
        my @protocol_types = map { $_->type } $phenotype_assay->protocols->all;

        if (
            grep {
                     $_->id == $ir_assay_base_term->id
                  || $ir_assay_base_term->has_child($_)
            } @protocol_types
          )
        {

            # yes we have an INSECTICIDE RESISTANCE BIOASSAY

  # We need several documents for each sample, one for every autocomplete entity
  # (e.g. Taxon, Projects, pubmedid, paper titles)

            foreach my $phenotype ( $phenotype_assay->phenotypes ) {

                my $assay_stable_id = $stable_id . "." . $phenotype->id;
                my $json_text;

                my @taxons = flattened_parents($stock_best_species);

                my $i = 0;
                foreach my $taxon (@taxons) {

                    # Taxonomy
                    my $documentTaxons = {
                        doc => {
                            id        => $assay_stable_id . "_taxon_" . $i,
                            stable_id => $assay_stable_id,
                            type      => 'Taxonomy',
                            bundle    => 'pop_sample_phenotype',
                            phenotype_type_s => 'insecticide resistance',
                            date             => $date,
                            geo_coords       => $latlong,
                            ( $i == 0 )
                            ? (
                                textboost => 100,
                                field     => 'species'
                              )
                            : (
                                textboost => 20,
                                field     => 'species_cvterms'
                            ),
                            textsuggest => $taxon,
                        }
                    };

                    $json_text = $json->encode($documentTaxons);
                    chomp($json_text);
                    print qq!"add": $json_text,\n!;
                    $i++;
                }

                # Description
                my $documentDescription = {
                    doc => {
                        id               => $assay_stable_id . "_desc",
                        stable_id        => $assay_stable_id,
                        type             => 'Description',
                        field            => 'description',
                        bundle           => 'pop_sample_phenotype',
                        phenotype_type_s => 'insecticide resistance',
                        geo_coords       => $latlong,
                        date             => $date,
                        textsuggest      => $stock->description || join(
                            ' ',
                            (
                                  $stock_best_species
                                ? $stock_best_species->name
                                : ()
                            ),
                            $stock->type->name,
                            ( $fc ? $fc->geolocation->summary : () )
                        ),
                    }
                };

                $json_text = $json->encode($documentDescription);
                chomp($json_text);
                print qq!"add": $json_text,\n!;

                # Title
                my $documentTitle = {
                    doc => {
                        id               => $assay_stable_id . "_title",
                        stable_id        => $assay_stable_id,
                        type             => 'Title',
                        field            => 'label',
                        bundle           => 'pop_sample_phenotype',
                        phenotype_type_s => 'insecticide resistance',
                        geo_coords       => $latlong,
                        date             => $date,
                        textsuggest      => $phenotype->name,

                    }
                };

                $json_text = $json->encode($documentTitle);
                chomp($json_text);
                print qq!"add": $json_text,\n!;

                # Stable ID
                my $documentID = {
                    doc => {
                        id               => $assay_stable_id . "_stable_id",
                        stable_id        => $assay_stable_id,
                        type             => 'Stable ID',
                        field            => 'id',
                        bundle           => 'pop_sample_phenotype',
                        phenotype_type_s => 'insecticide resistance',
                        geo_coords       => $latlong,
                        date             => $date,
                        textsuggest      => $assay_stable_id,

                    }
                };

                $json_text = $json->encode($documentID);
                chomp($json_text);
                print qq!"add": $json_text,\n!;

                # Pubmed ID(s)
                my @pubs = multiprops_pubmed_ids($stock);
                $i = 0;
                foreach my $pub (@pubs) {
                    my $documentPubmedIDs = {
                        doc => {
                            id        => $assay_stable_id . "_pmid_" . $i,
                            stable_id => $assay_stable_id,
                            bundle    => 'pop_sample_phenotype',
                            phenotype_type_s => 'insecticide resistance',
                            type             => 'Pubmed references',
                            field            => 'pubmed',
                            geo_coords       => $latlong,
                            date             => $date,
                            textsuggest      => "PMID:" . $pub,
                        }
                    };
                    $json_text = $json->encode($documentPubmedIDs);
                    chomp($json_text);
                    print qq!"add": $json_text,\n!;
                    $i++;
                }

                # Project(s)
                my @projects = $stock->projects;
                $i = 0;
                foreach my $project (@projects) {
                    my $documentProjects = {
                        doc => {
                            id        => $assay_stable_id . "_proj_" . $i,
                            stable_id => $assay_stable_id,
                            bundle    => 'pop_sample_phenotype',
                            phenotype_type_s => 'insecticide resistance',
                            type             => 'Projects',
                            geo_coords       => $latlong,
                            date             => $date,
                            textsuggest => quick_project_stable_id($project),
                            field       => 'projects',
                        }
                    };

                    $json_text = $json->encode($documentProjects);
                    chomp($json_text);
                    print qq!"add": $json_text,\n!;
                    $i++;
                }

                # Sample type
                my $documentSampleType = {
                    doc => {
                        id               => $assay_stable_id . "_sample_type",
                        stable_id        => $assay_stable_id,
                        type             => 'Sample type',
                        field            => 'sample_type',
                        bundle           => 'pop_sample_phenotype',
                        phenotype_type_s => 'insecticide resistance',
                        geo_coords       => $latlong,
                        date             => $date,
                        textsuggest      => $stock->type->name,

                    }
                };

                $json_text = $json->encode($documentSampleType);
                chomp($json_text);
                print qq!"add": $json_text,\n!;

                # Geolocations
                my @geolocations = remove_gaz_crap(
                    map { flattened_parents($_) }
                      map {
                        multiprops_cvterms( $_->geolocation, qr/^GAZ:\d+$/ )
                      } @field_collections
                );

                $i = 0;
                foreach my $geolocation (@geolocations) {

                    my $documentGeolocations = {
                        doc => {
                            id => $assay_stable_id . "_geolocation_" . $i,
                            stable_id        => $assay_stable_id,
                            type             => 'Geography',
                            bundle           => 'pop_sample_phenotype',
                            phenotype_type_s => 'insecticide resistance',
                            date             => $date,
                            geo_coords       => $latlong,
                            ( $i == 0 )
                            ? (
                                textboost => 100,
                                field     => 'geolocations_cvterms'
                              )
                            : (
                                textboost => 30,
                                field     => 'geolocations_cvterms'
                            ),
                            textsuggest => $geolocation,
                        }
                    };

                    $json_text = $json->encode($documentGeolocations);
                    chomp($json_text);
                    print qq!"add": $json_text,\n!;
                    $i++;
                }

                # Collection protocols

                my @collectionProtocols =
                  map { flattened_parents($_) } @collection_protocol_types;
                $i = 0;
                foreach my $protocol (@collectionProtocols) {

                    my $documentColProtocol = {
                        doc => {
                            id => $assay_stable_id . "_colProtocol_" . $i,
                            stable_id        => $assay_stable_id,
                            bundle           => 'pop_sample_phenotype',
                            phenotype_type_s => 'insecticide resistance',
                            type             => 'Collection protocols',
                            geo_coords       => $latlong,
                            date             => $date,
                            ( $i == 0 )
                            ? (
                                textboost => 100,
                                field     => 'collection_protocols_cvterms'
                              )
                            : (
                                textboost => 30,
                                field     => 'collection_protocols_cvterms'
                            ),
                            textsuggest => $protocol,
                        }
                    };

                    $json_text = $json->encode($documentColProtocol);
                    chomp($json_text);
                    print qq!"add": $json_text,\n!;
                    $i++;
                }

                # Protocols

                my @protocols = map { flattened_parents($_) } @protocol_types;
                $i = 0;
                foreach my $protocol (@protocols) {

                    my $documentProtocols = {
                        doc => {
                            id        => $assay_stable_id . "_protocol_" . $i,
                            stable_id => $assay_stable_id,
                            bundle    => 'pop_sample_phenotype',
                            phenotype_type_s => 'insecticide resistance',
                            type             => 'Protocols',
                            geo_coords       => $latlong,
                            date             => $date,
                            ( $i == 0 )
                            ? (
                                textboost => 100,
                                field     => 'protocols_cvterms'
                              )
                            : (
                                textboost => 30,
                                field     => 'protocols_cvterms'
                            ),
                            textsuggest => $protocol,
                        }
                    };

                    $json_text = $json->encode($documentProtocols);
                    chomp($json_text);
                    print qq!"add": $json_text,\n!;
                    $i++;
                }

                # Insecticides

                my ( $insecticide, $concentration, $concentration_unit,
                    $duration, $duration_unit, $sample_size, $errors )
                  = assay_insecticides_concentrations_units_and_more(
                    $phenotype_assay);

                die "assay $assay_stable_id had fatal issues: $errors\n"
                  if ($errors);

                if ( defined $insecticide ) {

                    my @insecticides = flattened_parents($insecticide);
                    $i = 0;
                    foreach my $insecticide (@insecticides) {

                        my $documentInsecticides = {
                            doc => {
                                id => $assay_stable_id . "_insecticide_" . $i,
                                stable_id        => $assay_stable_id,
                                bundle           => 'pop_sample_phenotype',
                                phenotype_type_s => 'insecticide resistance',
                                type             => 'Insecticides',
                                geo_coords       => $latlong,
                                date             => $date, 
                                ( $i == 0 )
                                ? (
                                    textboost => 100,

                                    # field     => 'insecticide_s'
                                    field => 'insecticide_cvterms'
                                  )
                                : (
                                    textboost => 30,
                                    field     => 'insecticide_cvterms'
                                ),
                                textsuggest => $insecticide,
                            }
                        };

                        $json_text = $json->encode($documentInsecticides);
                        chomp($json_text);
                        print qq!"add": $json_text,\n!;
                        $i++;
                    }
                }

            }
        }

    }

##########################################

    last if ( $limit && ++$done >= $limit );
}

# the commit is needed to resolve the trailing comma
print qq!\"commit\" : { } }\n!;

# returns just the 'proper' cvterms for all multiprops
# of the argument
# optional filter arg: regexp to match the ontology accession, e.g. ^GAZ:\d+$
sub multiprops_cvterms {
    my ( $object, $filter ) = @_;
    $filter //= qr/^\w+:\d+$/;
    return grep { $_->dbxref->as_string =~ $filter }
      map       { $_->cvterms } $object->multiprops;
}

# returns a list of pubmed ids (or empty list)
# if any multiprop comment value contains /pubmed/i and ends with (\d+)$
sub multiprops_pubmed_ids {
    my $object = shift;
    return map { $_->value =~ /pubmed.+?(\d+)$/i }
      grep     { ( $_->cvterms )[0]->name eq 'comment' } $object->multiprops;
}

# returns $lat, $long
sub stock_latlong {

    my $stock = shift;

    foreach my $experiment ( $stock->field_collections ) {
        if ( $stock->field_collections->count == 1 ) {
            my $geo = $experiment->nd_geolocation;
            if ( defined $geo->latitude && defined $geo->longitude ) {
                return ( join ",", $geo->latitude, $geo->longitude );
            }
        }
    }
    return undef;
}

# returns date of first assay with a date
sub stock_date {
    my $stock = shift;
    foreach my $assay ( $stock->nd_experiments ) {
        my $date = assay_date($assay);
        return $date if ($date);    # already iso8601 from assay_date
    }
    return undef;
}

# returns single date string
sub assay_date {
    my $assay       = shift;
    my @start_dates = $assay->multiprops($start_date_type);
    if ( @start_dates == 1 ) {
        return iso8601_date( $start_dates[0]->value );
    }
    my @dates = $assay->multiprops($date_type);
    if ( @dates == 1 ) {
        return iso8601_date( $dates[0]->value );
    }
    return undef;
}

# converts poss truncated string date into ISO8601 Zulu time (hacked with an extra Z for now)
sub iso8601_date {
    my $string   = shift;
    my $datetime = $iso8601->parse_datetime($string);
    if ( defined $datetime ) {
        return $datetime->datetime . "Z";
    }
}

#DEPRECATED
# returns an array of cvterms
# definitely want has child only (not IS also) because
# the insecticidal_substance term is used as a multiprop "key"
sub assay_insecticides {
    my $assay = shift;
    return grep { $insecticidal_substance->has_child($_) }
      map       { $_->cvterms } $assay->multiprops;
}

# returns these scalars
# 1. insecticide (cvterm)
# 2. concentration (number)
# 3. concentration unit (cvterm)
# 4. duration (number)
# 5. duration unit (cvterm)
# 6. sample size (number - no units needed)
# 7. error (string or empty/undef)
sub assay_insecticides_concentrations_units_and_more {
    my $assay = shift;
    my $insecticide;
    my $concentration;
    my $unit;
    my $duration;
    my $duration_unit;
    my $sample_size;
    my @errors;

    foreach my $multiprop ( $assay->multiprops ) {
        my @cvterms = $multiprop->cvterms;
        foreach my $cvterm (@cvterms) {
            if ( $insecticidal_substance->has_child($cvterm) ) {
                push @errors, "already got an insecticide"
                  if ( defined $insecticide );
                $insecticide = $cvterm;
            }
            elsif ( $cvterm->id == $concentration_term->id
                && defined $multiprop->value )
            {
                push @errors, "already got a concentration"
                  if ( defined $concentration );
                $concentration = $multiprop->value;
                $unit          = $cvterms[-1];        # units are always last
            }

            if ( $cvterm->id == $duration_term->id
                && defined $multiprop->value )
            {
                push @errors, "already got a duration" if ( defined $duration );
                $duration      = $multiprop->value;
                $duration_unit = $cvterms[-1];
            }

            if ( $cvterm->id == $sample_size_term->id
                && defined $multiprop->value )
            {
                push @errors, "already got a sample size"
                  if ( defined $sample_size );
                $sample_size = $multiprop->value;
            }
        }
    }
    return ( $insecticide, $concentration, $unit, $duration, $duration_unit,
        $sample_size, join ";", @errors );
}

# returns an array of (name, accession, name, accession, ...)
# now cached
my %term_id_to_flattened_parents;

sub flattened_parents {
    my $term = shift;
    my $id   = $term->id;
    $term_id_to_flattened_parents{$id} ||= [
        map {
            (
                $_->name, $_->cvtermsynonyms->get_column('synonym')->all,
                $_->dbxref->as_string
              )
        } ( $term, $term->recursive_parents_same_ontology )
    ];
    return @{ $term_id_to_flattened_parents{$id} };
}

#
# cached quick version
#
my %project_id_to_stable_id;

sub quick_project_stable_id {
    my $project = shift;
    my $id      = $project->id;
    return $project_id_to_stable_id{$id} ||= $project->stable_id;
}

#
# returns list of all key-value pairs for geo-coordinates
#
# arg 1 = latlong comma separated string
#
# uses global $gh object
#
sub geo_coords_fields {
    my $latlong = shift;
    my ( $lat, $long ) = split /,/, $latlong;
    die "some unexpected problem with latlog arg to geo_coords_fields\n"
      unless ( defined $lat && defined $long );

    my $geohash = $gh->encode( $lat, $long, 6 );

    return (
        geo_coords => $latlong,
        geohash_6  => $geohash,
        geohash_5  => substr( $geohash, 0, 5 ),
        geohash_4  => substr( $geohash, 0, 4 ),
        geohash_3  => substr( $geohash, 0, 3 ),
        geohash_2  => substr( $geohash, 0, 2 ),
        geohash_1  => substr( $geohash, 0, 1 )
    );
}

#
# phenotype_value_type
#
# pass a phenotype object, returns the term of the attribute or observable that is a child of 'quantitative qualifier'
#

sub phenotype_value_type {
    my $phenotype = shift;

    my $term;
    if (
        (
            defined( $term = $phenotype->observable )
            && (   $term->id == $quantitative_qualifier->id
                || $quantitative_qualifier->has_child($term) )
        )
        || (
            defined( $term = $phenotype->attr )
            && (   $term->id == $quantitative_qualifier->id
                || $quantitative_qualifier->has_child($term) )
        )
      )
    {
        return $term;
    }
    return;
}

#
# ohr = ordered hash reference
#
# return order-maintaining hash reference
# with optional arguments as key-value pairs
#
sub ohr {
    my $ref = {};
    tie %$ref, 'Tie::IxHash', @_;
    return $ref;
}

sub remove_gaz_crap {
    my @result;
    my $state = 1;
    foreach my $element (@_) {
        $state = 0
          if ( $element eq 'continent'
            || $element eq 'geographical location'
            || $element eq 'Oceans and Seas' );
        push @result, $element if ($state);
        $state = 1 if ( $element eq 'GAZ:00000448' );
    }
    return @result;
}
