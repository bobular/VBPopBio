package Bio::Chado::VBPopBio::ResultSet::Project::MetaProject;

use base 'Bio::Chado::VBPopBio::ResultSet::Project';
use Carp;
use strict;
use warnings;
use POSIX qw( strftime );
use aliased 'Bio::Chado::VBPopBio::Util::Multiprop';


=head1 NAME

Bio::Chado::VBPopBio::ResultSet::Project::MetaProject

=head1 SYNOPSIS

=head1 SUBROUTINES/METHODS

=head2 create_with

creates a metaproject from a resultset of stocks and a resultset of assays

It will NOT automatically make links to the relevant projects (from
the stocks/assays provided).  You need to provide a resultset of them.

Metaproject objects retrieved from the database will have the vanilla
Project class/type.

Usage:

  # do a chained query to get the stocks you want
  # note that these canned query methods may join the cvterm table a number of times,
  # this is why you have to specify type_2 the second time,
  # you also have to provide table (actually relationship) names to disambiguate *props value column

  $stocks_mali_2005 = $stocks->search_by_project({ 'project.name' => 'UC Davis/UCLA population dataset' })
                             ->search_by_nd_experimentprop({ 'type.name' => 'start date',
                                                             'nd_experimentprops.value' => { like => '2005%' } })
                             ->search_by_nd_geolocationprop({ 'type_2.name' => 'collection site country',
                                                              'nd_geolocationprops.value' => 'Mali' });


  # or you can chug through objects and make your own resultsets
  $stocks_cameroon = $schema->stocks;
  $stocks_array = [ your stocks go here ];
  $stocks_cameroon->set_cache($stocks_array);

  # make sure all resultsets have not already been iterated over (call reset method if this is the case)

  $metaproject = $metaprojects->create_with( { name => 'xyz',
                                               description => 'blah blah',
                                               external_id => 'META-ABC-DEF',
                                               stocks => $stocks,
                                               assays => $assays,
                                               projects => $projects,
                                             } );

Main method for creating a MetaProject

The stocks argument is a resultset for the stocks you want to add to the new project.

Assays is similar.

=cut

sub create_with {
  my ($self, $args) = @_;

  croak "no name and/or description\n" unless ($args->{name} && $args->{description});
  croak "no external_id\n" unless ($args->{external_id});
  croak "stocks resultset not given or is empty\n" unless (defined $args->{stocks} && eval { $args->{stocks}->count });
  croak "assays resultset not given or is empty\n" unless (defined $args->{assays} && eval { $args->{assays}->count });
  croak "projects resultset not given or is empty\n" unless (defined $args->{projects} && eval { $args->{projects}->count });

  my $stocks = $args->{stocks};
  my $assays = $args->{assays};
  my $projects = $args->{projects};
  my $external_id = $args->{external_id};

  my $schema = $self->result_source->schema;
  my $cvterms = $schema->cvterms;


  my $metaproject = $self->create( { # will fail if 'name' exists
				    name => $args->{name},
				    description => $args->{description},
				   } );

  # TO DO
  $metaproject->external_id($external_id);
  my $stable_id = $metaproject->stable_id;
  my $date_stamp = strftime("%Y-%m-%d", localtime);
  $metaproject->submission_date($date_stamp);
  $metaproject->public_release_date($date_stamp);

  # same for creation date (create it by asking for it)
  my $creation_date = $metaproject->creation_date;
  # more explicit udpate for modification date
  my $modification_date = $metaproject->update_modification_date;

  # add a projectprop "meta project"
  $metaproject->add_multiprop(Multiprop->new( cvterms=>[ $schema->types->metaproject ] ));

  # go through each stock, linking any nd_experiments to the new metaproject
  while (my $stock = $stocks->next) {
    $stock->add_to_projects($metaproject);
  }

  # link assays
  while (my $assay = $assays->next) {
    my $project_link = $assay->find_or_create_related('nd_experiment_projects',
						      { project => $metaproject });
  }

  # link it to existing project(s)
  my $derives_from = $cvterms->find_by_name({term_source_ref=>'OBO_REL', term_name => 'derives_from' });
  while (my $project = $projects->next) {
    $metaproject->find_or_create_related('project_relationship_subject_projects',
					 {
					  object_project => $project,
					  type => $derives_from,
					 });
  }

  return $metaproject;
}

=head1 AUTHOR

VectorBase, C<< <info at vectorbase.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2010 VectorBase.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;
