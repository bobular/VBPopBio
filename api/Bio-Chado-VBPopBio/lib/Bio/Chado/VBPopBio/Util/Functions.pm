package Bio::Chado::VBPopBio::Util::Functions;

use strict;
use warnings;
use Tie::IxHash;
# use Tie::Hash::Indexed;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(ordered_hashref);

=head1 NAME

Bio::Chado::VBPopBio::Util::Functions

=head1 SYNOPSIS

Exports functions like ordered_hash_ref

  use Bio::Chado::VBPopBio::Util::Functions qw/ordered_hashref/;

=cut

=head2 ordered_hashref

usage:

  my $hash = ordered_hash_ref();
  my $prefilled = ordered_hash_ref(foo=>123, bar=456);

=cut

sub ordered_hashref {
  my $ref = { };
  tie %$ref, 'Tie::IxHash', @_;
  return $ref;
}

1;
