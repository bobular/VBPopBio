package Bio::Chado::VBPopBio::Result::Protocol;

use strict;
use Carp;
use feature 'switch';
use base 'Bio::Chado::Schema::Result::NaturalDiversity::NdProtocol';
__PACKAGE__->load_components(qw/+Bio::Chado::VBPopBio::Util::Subclass/);
__PACKAGE__->subclass({ nd_experiment_protocols => 'Bio::Chado::VBPopBio::Result::Linker::ExperimentProtocol',
		        nd_protocolprops => 'Bio::Chado::VBPopBio::Result::Protocolprop',
			type => 'Bio::Chado::VBPopBio::Result::Cvterm',
		      });

use aliased 'Bio::Chado::VBPopBio::Util::Multiprops';
use aliased 'Bio::Chado::VBPopBio::Util::Multiprop';
use aliased 'Bio::Chado::VBPopBio::Util::Extra';

=head1 NAME

Bio::Chado::VBPopBio::Result::Protocol

=head1 SYNOPSIS

Protocol object with extra convenience functions.
Specialised experiment classes can be found in the.
Bio::Chado::VBPopBio::Result::Experiment::* namespace.

=head1 MANY-TO-MANY RELATIONSHIPS

=head2 nd_experiments

Type: many_to_many

Returns a list of nd_experiments

Related object: Bio::Chado::Schema::Result::NaturalDiversity::NdExperiment

=cut

__PACKAGE__->many_to_many
    (
     'nd_experiments',
     'nd_experiment_protocols' => 'nd_experiment',
    );


=head1 CONVENIENCE METHODS

=head2 create_nd_protocolprops

  Usage: $set->create_nd_protocolprops({ baz => 2, foo => 'bar' });
  Desc : convenience method to create experiment properties using cvterms
          from the ontology with the given name
  Args : hashref of { propname => value, ...},
         options hashref as:
          {
            autocreate => 0,
               (optional) boolean, if passed, automatically create cv,
               cvterm, and dbxref rows if one cannot be found for the
               given experimentprop name.  Default false.

            cv_name => cv.name to use for the given experimentprops.
                       Defaults to 'nd_protocol_property',

            db_name => db.name to use for autocreated dbxrefs,
                       default 'null',

            dbxref_accession_prefix => optional, default
                                       'autocreated:',
            definitions => optional hashref of:
                { cvterm_name => definition,
                }
             to load into the cvterm table when autocreating cvterms

             rank => force numeric rank. Be careful not to pass ranks that already exist
                     for the property type. The function will die in such case.

             allow_duplicate_values => default false.
                If true, allow duplicate instances of the same experiment
                and types in the properties of the experiment.  Duplicate
                types will have different ranks.
          }
  Ret  : hashref of { propname => new experimentprop object }

=cut

sub create_nd_protocolprops {
    my ($self, $props, $opts) = @_;

    # process opts
    $opts->{cv_name} = 'nd_protocol_property'
        unless defined $opts->{cv_name};
    return Bio::Chado::Schema::Util->create_properties
        ( properties => $props,
          options    => $opts,
          row        => $self,
          prop_relation_name => 'nd_protocolprops',
        );
}


=head1 SUBROUTINES/METHODS


=head2 add_multiprop

Adds normal props to the object but in a way that they can be
retrieved in related semantic chunks or chains.  E.g.  'insecticide'
=> 'permethrin' => 'concentration' => 'mg/ml' => 150 where everything
in single quotes is an ontology term.  A multiprop is a chain of
cvterms optionally ending in a free text value.

This is more flexible than adding a cvalue column to all prop tables.

Usage: $protocol>add_multiprop($multiprop);

See also: Util::Multiprop (object) and Util::Multiprops (utility methods)

=cut

sub add_multiprop {
  my ($self, $multiprop) = @_;

  return Multiprops->add_multiprop
    ( multiprop => $multiprop,
      row => $self,
      prop_relation_name => 'nd_protocolprops',
    );
}

=head2 multiprops

get a arrayref of multiprops

=cut

sub multiprops {
  my ($self, $filter) = @_;
  return Multiprops->get_multiprops
    ( row => $self,
      prop_relation_name => 'nd_protocolprops',
      filter => $filter,
    );
}

=head description

get/setter for description (stored via rank==0 prop)

usage

  $protocol->description("this is some text");
  print $protocol->description;


returns the text in both cases

=cut

sub description {
  my ($self, $description) = @_;
  return Extra->attribute
    ( value => $description,
      prop_type => $self->result_source->schema->types->description,
      prop_relation_name => 'nd_protocolprops',
      row => $self,
    );
}

=head uri

get/setter for uri (stored via rank==0 prop)

usage

  $protocol->uri("this is some text");
  print $protocol->uri;


returns the text in both cases

=cut

sub uri {
  my ($self, $uri) = @_;
  return Extra->attribute
    ( value => $uri,
      prop_type => $self->result_source->schema->types->uri,
      prop_relation_name => 'nd_protocolprops',
      row => $self,
    );
}

=head2 as_data_structure

return a hashref of hashrefs and arrays for JSON serialisation

=cut

sub as_data_structure {
  my ($self) = @_;

  return { name => $self->name,
	   description => $self->description,
	   uri => $self->uri,
	   type => $self->type->as_data_structure,
	   props => [ map { $_->as_data_structure } $self->multiprops ],
	 };
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

1; # End of Bio::Chado::VBPopBio::Result::Protocol
