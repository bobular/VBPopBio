package Bio::Chado::VBPopBio::ResultSet::Publication;

use strict;
use warnings;
use base 'DBIx::Class::ResultSet';
use Carp;
use aliased 'Bio::Chado::VBPopBio::Util::Multiprop';
use Digest::MD5 qw(md5_hex);

=head1 NAME

Bio::Chado::VBPopBio::ResultSet::Publication

=head1 SYNOPSIS


=head1 SUBROUTINES/METHODS

=head2 find_or_create_from_isatab

  Usage: $publications->find_or_create_from_isatab($publication_data)

Arguments:
  publication_data: hashref from $isatab_study->{study_publications}[$index]


The publication will be looked up in the database (for re-use) by
either PubMed ID, DOI or an MD5 hash of title+authors (whichever is
available).  The lookup includes the status term too.  If it already
exists, it will be re-used no-questions-asked (i.e. no verification
that the title, authors etc are the same).

=cut

sub find_or_create_from_isatab {
  my ($self, $publication_data) = @_;
  my $schema = $self->result_source->schema;

  # http://stackoverflow.com/questions/27910/finding-a-doi-in-a-document-or-page
  # see if non-empty $doi is badly formed
  my $doi = $publication_data->{study_publication_doi};
  if ($doi && $doi !~ qr{^(10[.][0-9]{4,}(?:[.][0-9]+)*/(?:(?!["&\'<>])\S)+)$}) {
    $schema->defer_exception("Publication DOI '$doi' is badly formed");
    $doi = '';
  }

  # also check pubmedID is good
  my $pubmed_id = $publication_data->{study_pubmed_id};
  if ($pubmed_id && $pubmed_id !~ /^\d+$/) {
    $schema->defer_exception("PubMedID '$pubmed_id' is badly formed");
    $pubmed_id = '';
  }

  # check for required args
  my @bad_args;
  $publication_data->{$_} or push @bad_args, $_
    for qw/study_publication_author_list
	   study_publication_title
	   study_publication_status
	   study_publication_status_term_accession_number
	   study_publication_status_term_source_ref/;
  if (@bad_args) {
    $schema->defer_exception("A publication is missing details for @bad_args");
    return;
  }

  # status = pub.type
  my $status = $schema->cvterms->find_by_accession
    ({
      term_source_ref => $publication_data->{study_publication_status_term_source_ref},
      term_accession_number => $publication_data->{study_publication_status_term_accession_number},
     });
  unless ($status) {
    $schema->defer_exception("couldn't find status ontology term ".join(':', @{$publication_data}{qw/study_publication_status_term_source_ref study_publication_status_term_accession_number/}));
    return;
  }

  if (not $pubmed_id and not $doi and $status->id == $schema->types->published->id) {
    $schema->defer_exception("publication was annotated as published but does not have a PubMed ID or DOI");
  }

  # uniquename is the mechanism by which we retrieve a previously-used publication
  # it's not perfect but it should be useful further down the line if we want to
  # use publication-project links
  my $uniquename = $publication_data->{study_pubmed_id} ||
                   $publication_data->{study_publication_doi} ||
		   # the following is a slice through a hashref
		   # it returns an array of values
                   md5_hex(join "\t", @{$publication_data}{qw/study_publication_title study_publication_author_list/});

  my $publication = $schema->publications->find_or_create
    ({
      uniquename => $uniquename,
      type => $status,
     });

  # if we got it back from the database, it will have a title already
  # if not, we need to add those fields
  unless ($publication->title) {
    # basic info
    $publication->update
      ({
	title => $publication_data->{study_publication_title},
	miniref => $pubmed_id,
	volumetitle => $doi,
       });
    # authors
    my $rank = 1;
    foreach my $author_string (split /[,;]\s*/, $publication_data->{study_publication_author_list}) {
      $publication->add_to_pubauthors({ surname => $author_string, rank => $rank++ });
    }
  }

  if (my $url = $publication_data->{comments}{URL}) {
    $publication->url($url);
  }

  return $publication;
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
