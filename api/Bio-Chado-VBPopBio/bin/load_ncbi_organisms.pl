#!/usr/bin/env perl

#
# usage: ./load_ncbi_organisms.pl ../../data/ncbi_taxonomy/
#
# these files need to be in the directory: nodes.dmp names.dmp
#

use strict;
use Carp;
use Bio::Chado::Schema;

my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
my $schema = Bio::Chado::Schema->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
my $ncbi_dir = shift;

my $organisms = $schema->resultset('Organism::Organism');
my $organism_dbxrefs = $schema->resultset('Organism::OrganismDbxref');
my $dbxrefs = $schema->resultset('General::Dbxref');

my $dbs = $schema->resultset('General::Db');
my $ncbi_taxon_db = $dbs->find_or_create({ name => 'NCBITaxon',
					   description => 'NCBI Taxonomy'
					 });

# we only load what we want
my @root_nodes = ( # 7165, # agam only for testing

		  6935, # Ixodida (ticks)
		  7157, # Culicidae (mosquitoes)

		   # either add more specific nodes or the one below
                  # 33340, # neoptera (includes mossies and rhodnius, glossina, pediculus)
);

die "no ncbi directory given\n" unless (-d $ncbi_dir);

die "Not all files there: nodes.dmp names.dmp\n"
  unless (-s "$ncbi_dir/nodes.dmp" &&
	  -s "$ncbi_dir/names.dmp");

my %required_taxon_ids;
my %parent2node;

open(NODES, "$ncbi_dir/nodes.dmp") or die;
while (<NODES>) {
  chomp;
  my ($taxon_id, $bar1, $parent_id, $bar2, $rank, $bar3, $embl_code, $bar4, $division_id) = split /\t/, $_;
  $parent2node{$parent_id}{$taxon_id} = 1;
}
close(NODES);

#
# recursively descend tree from the desired root nodes
#
# side effects are to fill in %required_taxon_ids
#

foreach my $root_node (@root_nodes) {
  descend_tree($root_node);
}

sub descend_tree {
  my $node = shift;
  $required_taxon_ids{$node} = 1;
  if ($parent2node{$node}) {
    foreach my $subnode (keys %{$parent2node{$node}}) {
      descend_tree($subnode);
    }
  }
}

my %common_names;

open(NAMES, "$ncbi_dir/names.dmp") or die;
while (<NAMES>) {
  chomp;
  my ($taxon_id, $bar1, $name, $bar2, $unique_name, $bar3, $name_class) = split /\t/, $_;
  if ($required_taxon_ids{$taxon_id}) {
    if ($name_class eq 'scientific name') {
      print "going to add >$name< for >$taxon_id<\n";

      my ($genus, $species) = split " ", $name, 2;
      $species = '' unless (defined $species); # we don't mind an empty species.

      my $organism = $organisms->find_or_create({
						 genus => $genus,
						 species => $species,
						},
						{ key => 'organism_c1' }
					       );

      my $dbxref = $dbxrefs->find_or_create({ db => $ncbi_taxon_db,
					      accession => $taxon_id,
					      version => '',
					      description => $name,
					    },
					    { key => 'dbxref_c1' }
					   );

      $organism->find_or_create_related('organism_dbxrefs',
					{
					 organism => $organism,
					 dbxref => $dbxref,
					}
				       );
      print "added organism $taxon_id ".$organism->genus." ".$organism->species."\n";

    } elsif ($name_class =~ /common name/) {
      # just take the first common name in the file
      $common_names{$taxon_id} ||= $name;
    }
  }

}
close(NAMES);


# now handle the common names and hope all the organism objects are already
# there

while (my ($taxon_id, $name) = (each %common_names)) {
  my $dbxref = $dbxrefs->find({
			       db => $ncbi_taxon_db,
			       accession => $taxon_id,
			       version => '',
			      },
			      { key => 'dbxref_c1' }
			     );

  my $organism_dbxrefs = $organisms->search_related('organism_dbxrefs',
						    { dbxref_id => $dbxref->dbxref_id }					    );

  my $count = $organism_dbxrefs->count;
  croak "no dbxref for $taxon_id (common name lookup)\n" unless ($count);
  croak "more than one organism per dbxref\n" if ($count > 1);

  my $organism = $organism_dbxrefs->first->organism;

  unless ($organism->common_name) {
    $organism->common_name($name);
    $organism->update;
    print "added common name '$name' for $taxon_id ".$organism->genus." ".$organism->species."\n";
  }
}
