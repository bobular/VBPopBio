package Bio::Chado::VBPopBio::Util::Date;

use strict;
use warnings;
use Carp;
use DateTime::Format::ISO8601;
use Try::Tiny;

=head1 NAME

Bio::Chado::VBPopBio::Util::Date

=head1 SYNOPSIS

Date handling utility functions.

=cut

my $iso8601 = DateTime::Format::ISO8601->new;

=head2 simple_validate_date

usage:

  use aliased 'Bio::Chado::VBPopBio::Util::Date';
  my $valid_date = Date->simple_validate_date($date, $project);

args: string, [row or resultset]

If the input string is defined, strip any time info.  If the remainder
is parsable by the ISO8601 rules, return that string.  Otherwise
return undef.

Optional DBIx Row or ResultSet object is used for throwing a deferred exception.

=cut

sub simple_validate_date {
  my ($class, $date, $row) = @_;
  my $valid_date;
  if (defined $date) {
    # check date format here
    # first strip any time info
    $date =~ s/T.*$//;
    # remove any trailing zero days/months
    while ($date =~ s/-00$//) { }
    try {
      my $dt = $iso8601->parse_datetime($date);
      # the parsing succeeded, ultimately return the original string
      # because the parser doesn't handle missing month or date info properly
      # (and there is no simple solution involving DateTime::Format::CLDR and DateTime::Incomplete)
      $valid_date = $date;
    } catch {
      if (defined $row) {
	$row->result_source->schema->defer_exception("Cannot parse date '$date' for project->submission_date");
      }
    }
  }
  return $valid_date;
}

1;
