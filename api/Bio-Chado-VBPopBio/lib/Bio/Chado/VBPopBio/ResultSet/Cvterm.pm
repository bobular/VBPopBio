package Bio::Chado::VBPopBio::ResultSet::Cvterm;

use strict;
use base 'Bio::Chado::Schema::Result::Cv::Cvterm::ResultSet';
use Carp;
use Memoize;

=head1 NAME

Bio::Chado::VBPopBio::ResultSet::Project

=head1 SYNOPSIS

Project resultset with extra convenience functions


=head1 SUBROUTINES/METHODS


=head2 create_with

Ensures cv option is our own subclass of Cv::Cv.

=cut

sub create_with {
  my ($self, $opts) = @_;
  my $schema = $self->result_source->schema;

  $opts->{cv} = 'null' unless defined $opts->{cv};

  # use, find, or create the given cv
  $opts->{cv} = ref $opts->{cv} ? $opts->{cv}
    : $schema->resultset('Cv') # our version of Cv
      ->find_or_create({ name => $opts->{cv} });

  return $self->SUPER::create_with($opts);
}

=head2 find_by_accession

Look up cvterm by dbxref provided by hashref argument
Returns a single cvterm or undef on failure.

Usage: $cvterm = $cvterms->find_by_accession({ term_source_ref => 'TGMA',
                                               term_accession_number => '0000000' });

Optional argument:
          prefered_term_source_ref => 'VBsp'
Forces a secondary dbxref lookup for a term which has a primary dbxref with db.name='VBsp'

e.g. term we want is loaded from VBcv as VBsp:0001234, with secondary
dbxref MIRO:0005678 We have data curated with MIRO:0005678 but we want
to annotate with the VBsp term.  If we looked up primary cvterm.dbxref
with MIRO:0005678 we'd get the MIRO term.  So we need to look up
cvterms connected to the dbxref via the cvterm_dbxref linker (many to
many).

If the secondary dbxref link can't be found, then the primary
referenced term is returned (e.g. the MIRO term in the example above).

=cut


sub find_by_accession {
  my ($self, $arg) = @_;
  if (defined $arg && defined $arg->{term_source_ref} && defined $arg->{term_accession_number}) {
    my $schema = $self->result_source->schema;
    #
    # temporary maybe?
    #
    if ($arg->{term_accession_number} =~ /^x+$/i) {
      $schema->defer_exception_once("Ontology term $arg->{term_source_ref}:$arg->{term_accession_number} replaced with placeholder");
      return $schema->types->placeholder;
    }

    my $dbxref = $schema->dbxrefs->find
      ({ accession => $arg->{term_accession_number},
	 version => '',
	 'db.name' => $arg->{term_source_ref}
       },
       { join => 'db' }
      );

    if ($dbxref &&
	$arg->{prefered_term_source_ref} &&
	$arg->{prefered_term_source_ref} ne $arg->{term_source_ref}) {
      my $secondary_search = $dbxref->cvterm_dbxrefs->search({ 'db.name' => $arg->{prefered_term_source_ref} },
							     { join => { cvterm => { dbxref => 'db' } } });

      if (my $first_linker = $secondary_search->next) {
	if ($secondary_search->next) {
	  $schema->defer_exception_once("Ontology term $arg->{term_source_ref}:$arg->{term_accession_number} has multiple secondary dbxref links to $arg->{prefered_term_source_ref}");
	} else {
	  return $first_linker->cvterm;
	}
      } else {
	# $schema->defer_exception_once("Ontology term $arg->{term_source_ref}:$arg->{term_accession_number} has no secondary dbxref links to $arg->{prefered_term_source_ref}");
	# change of plan, just return the cvterm via the primary dbxref
	return $dbxref->cvterm;
      }
    } elsif (defined $dbxref) {
      return $dbxref->cvterm;
    }
  }
  return undef; # on failure
}
sub normalize_fba_args {
  my ($self, $arg) = @_;
  if (defined $arg->{term_source_ref} && defined $arg->{term_accession_number}) {
    return "$arg->{term_source_ref}:$arg->{term_accession_number}";
  }
  return '';
}
memoize('find_by_accession', NORMALIZER=>'normalize_fba_args');

=head2 find_by_name

Look up cvterm by name, and dbxref->db->name (we can't trust cv.name because it can sometimes be verbose)

Returns a single cvterm or undef on failure.

Usage: $cvterm = $cvterms->find_by_accession({ term_source_ref => 'OBI',
                                               term_name => 'SNP microarray' });

=cut

sub find_by_name {
  my ($self, $arg) = @_;
  if (defined $arg && defined $arg->{term_source_ref} && defined $arg->{term_name}) {
    my $search = $self->result_source->schema->cvterms->search
      ({
	'me.name' => $arg->{term_name},
	'db.name' => $arg->{term_source_ref}
       },
       { join => { dbxref => 'db' }});

    if ($search->count() == 1) {
      return $search->first;
    }
  }
  return undef;
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
