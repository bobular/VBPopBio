package Bio::Chado::VBPopBio::Util::Extra;

use strict;
use warnings;
use Carp;

=head1 NAME

Bio::Chado::VBPopBio::Util::Extra

=head1 SYNOPSIS

Utility class for adding/retrieving simple string value attributes to
Chado entities via the relevant props table, like this

  package Bio::Chado::VBPopBio::Result::Experiment;
  use aliased 'Bio::Chado::VBPopBio::Util::Extra';

  # get/setter for description string
  sub description {
    my ($self, $description) = @_;
    # insert extra quality control on $description here
    return Extra->attribute
      ( value => $description,
	prop_type => $self->result_source->schema->types->description,
        prop_relation_name => 'nd_experimentprops',
        row => $self,
      );
  }

=head2 attribute

Generic getter/setter routine for re-use in arbitrary attribute methods,
such as $experiment->description()

The attributes are added as rank==0 props on the relevant table.
The prop.type is provided as an argument.

Single valued attributes only!

usage: developers only - see $experiment->description()

hash args: row => DBIx::Class Row or Result object
           prop_relation_name => DBIx props table relation name, e.g. 'stockprops'
           prop_type => Cvterm object
           value => optional value for 'set' version

returns: the string value if present, otherwise undefined

=cut

sub attribute {
  my ($class, %args) = @_;

  # check for required args
  $args{$_} or confess "must provide $_ arg"
    for qw/row prop_relation_name prop_type/;

  my $row = delete $args{row};
  my $prop_relation_name = delete $args{prop_relation_name};
  my $prop_type = delete $args{prop_type};
  my $result = delete $args{value};

  %args and confess "invalid option(s): ".join(', ', sort keys %args);

  confess "prop_type is not a Cvterm" unless ($prop_type->isa("Bio::Chado::VBPopBio::Result::Cvterm"));

  if (defined $result) {
    $row->find_or_create_related($prop_relation_name,
				  {
				   type => $prop_type,
				   value => $result,
				   rank => 0,
				  });
  } else {
    my $propsearch = $row->search_related($prop_relation_name,
					   {
					    type_id => $prop_type->id,
					    rank => 0,
					   });
    # next line is 3x faster than $propsearch->count == 1
    if ((my $prop = $propsearch->next) && !$propsearch->next) {
      $result = $prop->value;
    }
  }
  return $result;
}

1;
