package Bio::Chado::VBPopBio;

use warnings;
use strict;

use Mouse;
extends 'Bio::Chado::Schema';

use Bio::Chado::VBPopBio::Types;

# load all classes defined in Result/* and ResultSet/* (and subdirectories)
__PACKAGE__->load_namespaces();

=head1 NAME

Bio::Chado::VBPopBio

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

This is a layer on top of L<Bio::Chado::Schema> to simplify the manipulation of
natural diversity-related data.

    use Bio::Chado::VBPopBio;
    
    # connect to Chado
    my $dsn = "dbi:Pg:dbname=$ENV{CHADO_DB_NAME}";
    my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef, { AutoCommit => 1 });
    
    my $num_stocks = $schema->stocks->count();

=head1 ATTRIBUTES

=head2 types

A Bio::Chado::VBPopBio::Types object (which is really just a
convenience "factory" class returning cvterm objects.

e.g. $fc_type = $schema->types->field_collection;

=cut

has types => (
	      is => 'ro',
	      isa => 'Bio::Chado::VBPopBio::Types',
	      lazy => 1,
	      builder => '_build_types',
	     );


sub _build_types {
  my $self = shift;
  return Bio::Chado::VBPopBio::Types->new(schema=>$self);
}


=head1 SUBROUTINES/METHODS

The following methods just return a resultset.  Some are vanilla BCS some are BCNA.
We can easily change from BCS->BCNA here as required and avoid changes all over our
code.

=head2 stocks

Return a Stocks ResultSet


=cut

sub stocks {
  my $self = shift;
  return $self->resultset('Stock');
}

=head2 experiments

=cut

sub experiments {
  my $self = shift;
  return $self->resultset('Experiment');
}

=head2 assays

same as experiments

=cut

sub assays {
  my $self = shift;
  return $self->resultset('Experiment');
}


=head2 field_collections

Get resultset of C<Experiment::FieldCollection> objects only.

=cut

sub field_collections {
  my $self = shift;
  return $self->resultset('Experiment::FieldCollection');
}

=head2 phenotype_assays

Get resultset of C<Experiment::PhenotypeAssay> objects only.

=cut

sub phenotype_assays {
  my $self = shift;
  return $self->resultset('Experiment::PhenotypeAssay');
}

=head2 genotype_assays

Get resultset of C<Experiment::GenotypeAssay> objects only.

=cut

sub genotype_assays {
  my $self = shift;
  return $self->resultset('Experiment::GenotypeAssay');
}

=head2 species_identification_assays

Get resultset of C<Experiment::SpeciesIdentificationAssay> objects only.

=cut

sub species_identification_assays {
  my $self = shift;
  return $self->resultset('Experiment::SpeciesIdentificationAssay');
}

=head2 sample_manipulations

Get resultset of C<Experiment::SpeciesIdentificationAssay> objects only.

=cut

sub sample_manipulations {
  my $self = shift;
  return $self->resultset('Experiment::SampleManipulation');
}

=head2 projects

=cut

sub projects {
  my $self = shift;
  return $self->resultset('Project');
}

=head2 metaprojects

=cut

sub metaprojects {
  my $self = shift;
  return $self->resultset('Project::MetaProject');
}

=head2 geolocations

=cut

sub geolocations {
  my $self = shift;
  return $self->resultset('Geolocation');
}

=head2 cvterms

=cut

sub cvterms {
  my $self = shift;
  return $self->resultset('Cvterm');
}


=head2 dbs

=cut

sub dbs {
  my $self = shift;
  return $self->resultset('Db');
}

=head2 cvs

=cut

sub cvs {
  my $self = shift;
  return $self->resultset('Cv::Cv');
}

=head2 dbxrefs

=cut

sub dbxrefs {
  my $self = shift;
  return $self->resultset('Dbxref');
}

=head2 protocols

=cut

sub protocols {
  my $self = shift;
  return $self->resultset('Protocol');
}

=head2 genotypes

=cut

sub genotypes {
  my $self = shift;
  return $self->resultset('Genotype');
}

=head2 phenotypes

=cut

sub phenotypes {
  my $self = shift;
  return $self->resultset('Phenotype');
}

=head2 organisms

=cut

sub organisms {
  my $self = shift;
  return $self->resultset('Organism');
}

=head2 publications

=cut

sub publications {
  my $self = shift;
  return $self->resultset('Publication');
}

=head2 contacts

=cut

sub contacts {
  my $self = shift;
  return $self->resultset('Contact');
}

=head1 EXCEPTION HANDLING

=head2 txn_do_deferred

Runs the coderef but checks for accumulated errors from $self->defer_exception() before committing.
Exploits the property of nested transactions to commit only at the outermost layer.

=cut

sub txn_do_deferred {
  my ($self, $coderef, @args) = @_;

  my $retval;
  $self->txn_do( sub {
		   $self->{deferred_exceptions} = [];
		   $retval = $self->txn_do($coderef, @args);
		   if (@{$self->{deferred_exceptions}}) {
		     warn "The following deferred exceptions were encountered:\n  ".
		       join("\n  ", @{$self->{deferred_exceptions}})."\nRolling back...\n";
		     $self->txn_rollback();
		   }
		 }
	       );
  return $retval;
}


=head2 defer_exception

arg: message

Tosses an exception (well, a message at least) on the stack for reporting later (see txn_do_deferred)

=cut

sub defer_exception {
  my ($self, $msg) = @_;
  push @{$self->{deferred_exceptions}}, $msg;
}

=head2 defer_exception_once

arg: message

Tosses an exception (well, a message at least) on the stack for reporting later (see txn_do_deferred),
but if an identical message is already there then it won't add another.

Inefficiently implemented without hash lookups but this should not matter when loading error-free data.

=cut

sub defer_exception_once {
  my ($self, $msg) = @_;
  push @{$self->{deferred_exceptions}}, $msg unless (grep { $_ eq $msg } @{$self->{deferred_exceptions}}) ;
}


=head2 disabling postgres statement preparation

This can be done in a manual connect.

  my $schema = Bio::Chado::VBPopBio->connect($dsn, $ENV{USER}, undef,
                                             { AutoCommit => 1, pg_server_prepare => 0 });

But in Dancer it's not possible to use the config.yaml file or even
hardcoded schema->storage->... in the webservice code.

So instead we use Mouse to wrap around the connect method.

=cut

around 'connect' => sub {
      my $orig = shift;
      my $self = shift;

      my ($dsn, $user, $password, $options) = @_;
      $options->{pg_server_prepare} = 0;

      $self->$orig($dsn, $user, $password, $options);
  };



__PACKAGE__->meta->make_immutable;

=head1 AUTHOR

VectorBase, C<< <info at vectorbase.org> >>

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2010 VectorBase.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;
