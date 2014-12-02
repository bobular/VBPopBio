package Bio::Chado::VBPopBio::ResultSet::Contact;

use strict;
use warnings;
use base 'DBIx::Class::ResultSet';
use Carp;
use aliased 'Bio::Chado::VBPopBio::Util::Multiprop';


=head1 NAME

Bio::Chado::VBPopBio::ResultSet::Contact

=head1 SYNOPSIS


=head1 SUBROUTINES/METHODS

=head2 find_or_create_from_isatab

  Usage: $contacts->find_or_create_from_isatab($contact_data)

Arguments:
  contact_data: hashref from $isatab_study->{study_contacts}[$index]


The contact will be looked up in the database (for re-use) by the ISA-Tab field
$contact_data->{study_person_email}.  If it already exists, it will be re-used
no-questions-asked (i.e. no verification of other fields).

The Chado contact object will be loaded as follows

  contact.name = email address
  contact.description = "Alan N. Other (Imperial College London)" or "Alan N. Other" or "Other"

The description will be truncated somehow to 255 characters.

Limitations:

  As there are no contactprops or project_contactprops tables we can't
  really load the roles (needs to go on latter table) or individual
  fields such as institution (would need to be in contactprops).

  It should possibly (but does not currently) update names and
  addresses when re-using existing contact table entries (imagine that
  someone may have moved institution.  Easy to do if required.

=cut

sub find_or_create_from_isatab {
  my ($self, $contact_data) = @_;
  my $schema = $self->result_source->schema;
  my $email = $contact_data->{study_person_email};
  my $surname = $contact_data->{study_person_last_name};

  # some arg checking
  if (!defined $surname && !defined $email) {
    $schema->defer_exception_once("A study contact is missing mandatory surname and email info. Only data provided was: >".join(":", values %$contact_data)."<");
    return;
  }
  unless (defined $surname) {
    $schema->defer_exception_once("Missing last name for study person $email");
    return;
  }
  unless (defined $email) {
    $schema->defer_exception_once("Missing email for study person $surname");
    return;
  }

  # now get down to business
  my $contact = $schema->contacts->find_or_create
    ({
      name => $email
     });

  # if we got it back from the database, it will have a description already
  # if not, we need to add those fields
  unless ($contact->description) {
    my $type = $schema->types->person;
    $contact->type($type);

    my $name = join ' ',
      grep $_,
	$contact_data->{study_person_first_name},
	@{$contact_data->{study_person_mid_initials} // []},
	$surname;
    my $place = join ', ',
      grep $_,
	$contact_data->{study_person_affiliation},
	$contact_data->{study_person_address};
    my $description = $name;
    $description .= " ($place)" if ($place && length($description)+length($place)+3 < 255);

    # tidy up errant multiple whitespace
    $description =~ s/\s+/ /g;
    $description =~ s/\s+$//;
    $description =~ s/^\s+//;

    $contact->description($description);

    $contact->update;
  }

  return $contact;
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
