package Bio::Chado::VBPopBio::Util::Multiprops;

use strict;
use warnings;
use Carp;
use Memoize;

use aliased 'Bio::Chado::VBPopBio::Util::Multiprop';

my $MAGIC_VALUE = ',';

=head1 NAME

Bio::Chado::VBPopBio::Util::Multiprops

=head1 SYNOPSIS

Utility class for adding/retrieving multiprops
(similar to Bio::Chado::Schema::Util)

Currently implemented as "add only", for simplicity, although will not
add the same multiprop twice (which implies that you can't specify the
rank of a multiprop before you add it, although this could change in
the future).

=head2 add_multiprop

Returns the multiprop that was passed (but this should now have its rank attribute set).

If the multiprop was already attached then it won't add a duplicate.

hash args: row => DBIx::Class Row or Result object
           prop_relation_name => DBIx props table relation name, e.g. 'stockprops'
           multiprop => Multiprop object

=cut

sub add_multiprop {
  my ($class, %args) = @_;

  # check for required args
  $args{$_} or confess "must provide $_ arg"
    for qw/row prop_relation_name multiprop/;

  my $row = delete $args{row};
  my $multiprop = delete $args{multiprop};
  my $prop_relation_name = delete $args{prop_relation_name};

  %args and confess "invalid option(s): ".join(', ', sort keys %args);

  # perform the (expensive!) check for existing multiprops
  my $input_json = undef;
  foreach my $existing_multiprop ($row->multiprops) {
    $input_json //= $multiprop->as_json; # only make $input_json if there are existing multiprops
    return $existing_multiprop if ($existing_multiprop->as_json eq $input_json);
  }

  # find the highest rank of existing props
  my $max_rank = $row->$prop_relation_name->get_column('rank')->max;

  # ignore negative ranks and default to zero
  $max_rank = 0 unless (defined $max_rank && $max_rank > 0);

  # assign next available rank for the first cvterm of the new multiprop
  my $rank = $max_rank + 1;

  defined $multiprop->rank and confess "predefined rank not yet handled in add_multiprop";

  # set the rank on the passed object in case the caller wants to
  $multiprop->rank($rank);

  my $last_prop; # keep track so we can add the value if needed
  foreach my $cvterm ($multiprop->cvterms) {
    $last_prop = $row->create_related($prop_relation_name,
					      { type => $cvterm,
						rank => $rank++,
						value => $MAGIC_VALUE # subject to change below
					      });
  }

  # if value is undef, then we will terminate the chain with NULL in database
  # if it's a comma then that means the chain continues (comma == MAGIC VALUE)
  # if it's a non-comma value that also terminates the chain
  my $value = $multiprop->value;
  confess "magic value '$MAGIC_VALUE' is not allowed as a multiprop value"
    if (defined $value && $value eq $MAGIC_VALUE);
  $last_prop->value($value);
  $last_prop->update();

  return $multiprop;
}

=head2 get_multiprops

Retrieve props and process them into multiprops

hash args: row => DBIx::Class Row or Result object
           prop_relation_name => DBIx props table relation name, e.g. 'stockprops'

           # the following OPTIONAL arg is for internal use (see multiprops method in some Result classes)
           filter => Cvterm object - returns the multiprops with this exact term first in chain.

Returns a perl list of multiprops

Does NOT return props with ranks <= 0.

=cut

sub get_multiprops {
  my ($class, %args) = @_;

  # check for required args
  $args{$_} or confess "must provide $_ arg"
    for qw/row prop_relation_name/;

  my $row = delete $args{row};
  my $prop_relation_name = delete $args{prop_relation_name};
  my $filter = delete $args{filter};

  confess "filter option requires a Cvterm object" unless (!defined $filter || $filter->isa("Bio::Chado::VBPopBio::Result::Cvterm"));

  %args and confess "invalid option(s): ".join(', ', sort keys %args);


  # get the positive-ranked props and order them by rank
  my $props = $row->$prop_relation_name->search({}, { where => { rank => { '>' => 0 } },
						      order_by => 'rank',
						      prefetch => { type => { 'dbxref' => 'db' } },
						      result_class => 'DBIx::Class::ResultClass::HashRefInflator',
						    });

  # props resultset returns PLAIN HASHREF results - for speed

  # step through the props pushing them into different baskets
  # splitting on an undefined value or non-comma value.
  my @prop_groups;
  my $index = 0;
  while (my $prop = $props->next) {
    push @{$prop_groups[$index]}, $prop;
    $index++ unless (defined $prop->{value} && $prop->{value} eq $MAGIC_VALUE);
  }

  # convert prop groups into multiprops
  my @multiprops;
  foreach my $prop_group (@prop_groups) {
    my @cvterm_ids = map { $_->{type}->{cvterm_id} } @{$prop_group};
    my $rank = $prop_group->[0]->{rank};
    my $value = pop(@{$prop_group})->{value};

    confess "value should not be magic value '$MAGIC_VALUE'"
      if (defined $value && $value eq $MAGIC_VALUE);
    if (!defined $filter || $filter->cvterm_id == $cvterm_ids[0]) {
      push @multiprops, build_multiprop($row, $value, $rank, @cvterm_ids);
# was
#     push @multiprops, Multiprop->new(cvterms => \@cvterms,
#				       value => $value,
#				       rank => $rank,);
    }
  }
  # if we're filtering (and didn't find the multiprop we wanted) then return nothing!
  return @multiprops;
}


#
# private helper that is memoized
#
sub build_multiprop {
  my ($row, $value, $rank, @cvterm_ids) = @_;
  my $cvterms = $row->result_source->schema->cvterms;
  return Multiprop->new( cvterms => [ map { $cvterms->find($_) } @cvterm_ids ], value => $value, rank => $rank );
}
sub normalise_bm_args {
  my ($row_ignore, @args) = @_;
  return join ':', map { $_ // '' } @args;
}
memoize('build_multiprop', NORMALIZER=>'normalise_bm_args');

=head2 add_multiprops_from_isatab_characteristics

usage Multiprops->add_multiprops_from_isatab_characteristics
        ( row => $stock,
          prop_relation_name => 'stockprops',
          characteristics => $study->{samples}{my_sample}{characteristics} );

Adds a multiprop to the Chado object for each "Characteristics [xxx (ONTO:accession)] column.
If the column heading is not ontologised or the term can't be found, an exception will be thrown.
Units will be added as appropriate.

If term_source_ref and term_accession_number are semicolon
delimited (the same number of items) then multiple multiprops will be
added for that column.

=cut

sub add_multiprops_from_isatab_characteristics {
  my ($class, %args) = @_;

  # check for required args
  $args{$_} or confess "must provide $_ arg"
    for qw/row prop_relation_name characteristics/;

  my $row = delete $args{row};
  my $characteristics = delete $args{characteristics};
  my $prop_relation_name = delete $args{prop_relation_name};

  %args and confess "invalid option(s): ".join(', ', sort keys %args);

  my $schema = $row->result_source->schema;

  # for each characteristics column
  while (my ($cname, $cdata) = each %{$characteristics}) {
    # first handle the column name (first term in multiprop sentence)
    if ($cname =~ /\((\w+):(\w+)\)/) {
      my ($onto, $acc) = ($1, $2);
      my $cterm = $schema->cvterms->find_by_accession
	({
	  term_source_ref => $onto,
	  term_accession_number => $acc
	 });
      if ($cterm) {
	# handle special case of semicolon delimited ontology values
	my @refs = split /;/, $cdata->{term_source_ref} // '';
	my @accs = split /;/, $cdata->{term_accession_number} // '';
	if (@refs > 1 && @accs == @refs) {
	  for (my $i=0; $i<@refs; $i++) {
	    my $vterm = $schema->cvterms->find_by_accession({ term_source_ref => $refs[$i],
							      term_accession_number => $accs[$i],
							      prefered_term_source_ref => $cdata->{prefered_term_source_ref}});
	    $schema->defer_exception_once("$cname column failed to find ontology term for '$refs[$i]:$accs[$i]'") unless (defined $vterm);
	    $class->add_multiprop
	      ( row => $row,
		prop_relation_name => $prop_relation_name,
		multiprop => Multiprop->new(cvterms=>[ $cterm, $vterm ])
	      );
	  }
	} else { # just carry on - if delimiting is unbalanced the next bit will fail gracefully
	  my @cvterms;
	  # now handle value
	  my $value = $cdata->{value};
	  my $vterm = $schema->cvterms->find_by_accession($cdata);
	  my $uterm = $schema->cvterms->find_by_accession($cdata->{unit});
	  if ($uterm && defined $value && length($value)) {
	    # case 1: free text value with units
	    @cvterms = ($cterm, $uterm);
	    $schema->defer_exception_once("$cname value $value cannot be ontology term and have units") if ($vterm);
	  } elsif ($vterm) {
	    # case 2: cvterm value
	    @cvterms = ($cterm, $vterm);
	    $value = undef;
	  } else {
	    # case 3: free text value no units
	    @cvterms = ($cterm);
	    # but throw some errors if we were expecting to have ontology term for value
	    $schema->defer_exception_once("$cname value $value failed to find ontology term for '$cdata->{term_source_ref}:$cdata->{term_accession_number}'") if ($cdata->{term_source_ref} && $cdata->{term_accession_number});
	    # or units
	    $schema->defer_exception_once("$cname value $value unit ontology lookup error '$cdata->{unit}{term_source_ref}:$cdata->{unit}{term_accession_number}'") if ($cdata->{unit}{term_source_ref} && $cdata->{unit}{term_accession_number});
	  }
	  $class->add_multiprop
	    ( row => $row,
	      prop_relation_name => $prop_relation_name,
	      multiprop => Multiprop->new(cvterms=>\@cvterms, value=>$value) );
	}
      } else {
	$schema->defer_exception_once("Characteristics [$cname] - can't find ontology term via $onto:$acc");
      }
    } else {
      $schema->defer_exception_once("Characteristics [$cname] - does not contain ontology accession - skipping column.");
    }
  }
}

=head2 add_multiprops_from_isatab_comments

usage Multiprops->add_multiprops_from_isatab_comments
        ( row => $stock,
          prop_relation_name => 'stockprops',
          comments => $study->{samples}{my_sample}{comments} );

Adds a multiprop to the Chado object for each "Comments [some topic or other] column.
If the column heading is not ontologised or the term can't be found, an exception will be thrown.
Units will be added as appropriate.

=cut

sub add_multiprops_from_isatab_comments {
  my ($class, %args) = @_;

  # check for required args
  $args{$_} or confess "must provide $_ arg"
    for qw/row prop_relation_name comments/;

  my $row = delete $args{row};
  my $comments = delete $args{comments};
  my $prop_relation_name = delete $args{prop_relation_name};

  %args and confess "invalid option(s): ".join(', ', sort keys %args);

  my $schema = $row->result_source->schema;

  my $comment_term = $schema->types->comment;

  # for each comments column
  while (my ($cname, $cdata) = each %{$comments}) {
    my $text = "[$cname] $cdata";
    $class->add_multiprop
      ( row => $row,
	prop_relation_name => $prop_relation_name,
	multiprop => Multiprop->new(cvterms=>[ $comment_term ], value=>$text) );
  }
}

1;
