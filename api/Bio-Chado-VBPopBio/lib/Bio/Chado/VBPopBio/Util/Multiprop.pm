package Bio::Chado::VBPopBio::Util::Multiprop;

use Mouse;
use JSON;

=head1 NAME

Bio::Chado::VBPopBio::Util::Multiprop

=head1 SYNOPSIS

  use aliased 'Bio::Chado::VBPopBio::Util::Multiprop';
  $multiprop = new Multiprop(cvterms => [ $cvterm1 => $cvterm2 => $cvterm3 ], value => 150);

  SOP might be to add multiprops even where there is only one cvterm - for consistency!

=head1 ATTRIBUTES

=head2 cvterms

arrayref of Bio::Chado::VBPopBio::Result::Cvterm

=cut

has 'cvterms' => (
		  is => 'ro',
		  isa => 'ArrayRef[Bio::Chado::VBPopBio::Result::Cvterm]',
		  auto_deref => 1,
		  required => 1,
		 );

=head2 value

optional string value

=cut

has 'value' => (
		is => 'rw',
		isa => 'Maybe[Str]',
		required => 0,
	       );

=head2 rank

This will be undefined if the multiprop hasn't yet been inserted into the database.

Not currently used for anything meaningful, but will be useful when/if we allow
overwriting/replacement of existing multiprops.

=cut

has 'rank' => (
		is => 'rw',
		isa => 'Int',
		required => 0,
	       );


=head2 as_data_structure

returns a data structure suitable for JSONification

=cut

sub as_data_structure {
  my $self = shift;
  return { cvterms => [ map { $_->as_data_structure } $self->cvterms ],
	   defined $self->value ? (value => $self->value) : (),
	   # rank => $self->rank,  # don't waste bandwidth until needed
	 };
}

=head2 as_string

Simple string version of multiprop.  Comma separated cvterm names and optional free text value.

=cut

sub as_string {
  my $self = shift;
  return join ", ", (map { $_->name } $self->cvterms), defined $self->value ? ($self->value) : ();
}

=head2 as_json

returns a JSON version of as_data_structure

in general we DO NOT want to provide JSON methods for Result classes -
this is a special case where the JSON is used for checking uniqueness
(see Multiprops.pm)

=cut

sub as_json {
  my $self = shift;
  return encode_json($self->as_data_structure);
}

1;
