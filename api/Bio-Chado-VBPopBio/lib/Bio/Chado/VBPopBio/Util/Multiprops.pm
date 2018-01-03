package Bio::Chado::VBPopBio::Util::Multiprops;

use strict;
use warnings;
use Carp;
use Memoize;
use Bio::Chado::VBPopBio::Util::Functions qw/ordered_hashref/;

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
           allow_duplicates => (optional) scalar, if true, skip the duplicate property check and add willy nilly

=cut

sub add_multiprop {
  my ($class, %args) = @_;

  # check for required args
  $args{$_} or confess "must provide $_ arg"
    for qw/row prop_relation_name multiprop/;

  my $row = delete $args{row};
  my $multiprop = delete $args{multiprop};
  my $prop_relation_name = delete $args{prop_relation_name};
  my $allow_duplicates = delete $args{allow_duplicates};

  %args and confess "invalid option(s): ".join(', ', sort keys %args);

  # perform the (expensive!) check for existing multiprops
  unless ($allow_duplicates) {
    my $input_json = undef;
    foreach my $existing_multiprop ($row->multiprops) {
      $input_json //= $multiprop->as_json; # only make $input_json if there are existing multiprops
      return $existing_multiprop if ($existing_multiprop->as_json eq $input_json);
    }
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

  my $multiprops = ordered_hashref(); # grouplabel or onto:acc => multiprop

  # for each characteristics column
  while (my ($cname, $cdata) = each %{$characteristics}) {
    # first handle the column name (first term in multiprop sentence)
    # could be "Characteristics [organism part (EFO:0000635)]" or "Characteristics [grouplabel.organism part (EFO:0000635)]"
    if ($cname =~ /^\s*(?:(\w+)\.)?.+\((\w+):(\w+)\)/) {
      my ($grouplabel, $onto, $acc) = ($1, $2, $3);

      my $multiprop_key = $grouplabel // "$onto:$acc";

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
	  if (defined $grouplabel) {
	    $schema->defer_exception_once("grouped characteristics column '$cname' cannot contain semicolon delimited term values");
	  } else {
	    for (my $i=0; $i<@refs; $i++) {
	      my $vterm = $schema->cvterms->find_by_accession({ term_source_ref => $refs[$i],
								term_accession_number => $accs[$i],
								prefered_term_source_ref => $cdata->{prefered_term_source_ref}});
	      $schema->defer_exception_once("$cname column failed to find ontology term for '$refs[$i]:$accs[$i]'") unless (defined $vterm);

	      $multiprops->{"$multiprop_key.$i"} = Multiprop->new(cvterms => [ $cterm, $vterm ]);
	    }
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

	  # we'll build the multiprop either from a half-made one or a new empty one
	  my $mprop = $multiprops->{$multiprop_key} ||= Multiprop->new(cvterms => [ ]);
	  push @{$mprop->cvterms}, @cvterms;

	  # however, if the multiprop already has a value, we can't do anything with it
	  if (defined $mprop->value) {
	    # if we pulled out out of the $multiprops cache it should have an undefined value attribute
	    $schema->defer_exception_once("Free text value not allowed for non-final grouped characteristic in column preceding '$cname'");
	  } else {
	    $mprop->value($value);
	  }
	}
      } else {
	$schema->defer_exception_once("Characteristics [$cname] - can't find ontology term via $onto:$acc");
      }
    } else {
      $schema->defer_exception_once("Characteristics [$cname] - does not contain ontology accession - skipping column.");
    }
  }

  # add the fully-fledged multiprops to the item now
  foreach my $mprop (values %{$multiprops}) {
    $class->add_multiprop
      ( row => $row,
	prop_relation_name => $prop_relation_name,
	multiprop => $mprop );
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


=head2 to_isatab

convert multiprops to ISA-Tab data structure

returns ($comments, $characteristics)


=cut

sub to_isatab {
  my ($class, $row) = @_;
  my $comments = ordered_hashref();
  my $characteristics = ordered_hashref();

  my $schema = $row->result_source->schema;
  my $comment_term_id = $schema->types->comment->id;

  # handle all multiprops (characteristics and comments)

  my $type2characteristics = ordered_hashref; # need to collate all props of the same type (to output semicolon delimited)
  # key "ONTO:ACC" => [ multiprop, ... ]

  foreach my $multiprop ($row->multiprops) {
    my @cvterms = $multiprop->cvterms;
    my $value = $multiprop->value;
    my $mprop_type = $cvterms[0];
    if ($mprop_type->id == $comment_term_id) {
      # render as ISA-Tab comment
      my ($heading, $text) = $value =~ /\[(.+?)\] (.+)/;
      $schema->defer_exception("can't parse comment multiprop in stock->as_isatab()") unless (defined $heading && defined $text);
      $comments->{$heading} = $text;
    } else {
      # it must be a characteristic
      my $key = $mprop_type->dbxref->as_string();
      push @{$type2characteristics->{$key}}, $multiprop;
    }
  }
  # now render the characteristics to isatab
  my $groupnum = 1;
  foreach my $key (keys %{$type2characteristics}) {
    my $multiprops = $type2characteristics->{$key};
    my ($mprop_type) = $multiprops->[0]->cvterms; # first cvterm of first multiprop (all share the same first cvterm)

    my $done_multiprops = 0;
    if (@$multiprops > 1) {
      my $heading = sprintf "%s (%s)", $mprop_type->name, $mprop_type->dbxref->as_string;
      # the values should be all ontology terms or all free text (and perhaps units)
      # so let's test if they are all ontology term values
      my ($num_ontology_term_vals, $num_values_with_units, $num_plain_vals) = (0,0,0);
      map {
	if (@{$_->cvterms} == 2) {
	  if (defined $_->value) {
	    $num_values_with_units++;
	  } else {
	    $num_ontology_term_vals++;
	  }
	} elsif (@{$_->cvterms} == 1 && defined $_->value) {
	  $num_plain_vals++;
	} else {
	  my $num = @{$_->cvterms};
	}
      } @$multiprops;

      if ($num_ontology_term_vals == @$multiprops) {
	$characteristics->{$heading}{value} = join ';', map { ($_->cvterms)[1]->name } @$multiprops;
	$characteristics->{$heading}{term_source_ref} = join ';', map { ($_->cvterms)[1]->dbxref->db->name } @$multiprops;
	$characteristics->{$heading}{term_accession_number} = join ';', map { ($_->cvterms)[1]->dbxref->accession } @$multiprops;
	$done_multiprops = 1;
      } elsif ($num_values_with_units == @$multiprops) {
	$characteristics->{$heading}{value} = join ';', map { $_->value } @$multiprops;
	$characteristics->{$heading}{unit}{value} = join ';', map { ($_->cvterms)[1]->name } @$multiprops;
	$characteristics->{$heading}{unit}{term_source_ref} = join ';', map { ($_->cvterms)[1]->dbxref->db->name } @$multiprops;
	$characteristics->{$heading}{unit}{term_accession_number} = join ';', map { ($_->cvterms)[1]->dbxref->accession } @$multiprops;
	$done_multiprops = 1;
      } elsif ($num_plain_vals == @$multiprops) {
	$characteristics->{$heading}{value} = join ';', map { $_->value } @$multiprops;
	$done_multiprops = 1;
      } else {
	# warn "uncaught multiprop condition: key=$key num_plain=$num_plain_vals num_onto=$num_ontology_term_vals num_units=$num_values_with_units";
      }
      # warn "this code hasn't been tested and doesn't have much error checking";
    }
    unless ($done_multiprops) {
      foreach my $multiprop (@$multiprops) {
	my $value = $multiprop->value;
	my @cvterms = $multiprop->cvterms;
	if (@cvterms > 2) {
	  # needs group prefix to render proper multiprop to multiple Characteristics columns
	  my $group_prefix = sprintf "group%d", $groupnum++;
	  for (my $i=0; $i<@cvterms; $i+=2) {
	    my ($term1, $term2) = ($cvterms[$i], $cvterms[$i+1]);
	    my $reached_the_end = $i >= @cvterms-2;
	    my $heading = sprintf "%s.%s (%s)", $group_prefix, $term1->name, $term1->dbxref->as_string;
	    if ($reached_the_end) {
	      if (defined $value && defined $term2) {
		# we have units
		$characteristics->{$heading}{value} = $value;
		$characteristics->{$heading}{unit}{value} = $term2->name;
		$characteristics->{$heading}{unit}{term_source_ref} = $term2->dbxref->db->name;
		$characteristics->{$heading}{unit}{term_accession_number} = $term2->dbxref->accession;
	      } elsif (defined $value) {
		# we have unitless free text value
		$characteristics->{$heading}{value} = $value;
	      } elsif (defined $term2) {
		# we have an ontology term value
		$characteristics->{$heading}{value} = $term2->name;
		$characteristics->{$heading}{term_source_ref} = $term2->dbxref->db->name;
		$characteristics->{$heading}{term_accession_number} = $term2->dbxref->accession;
	      } else {
		$schema->defer_exception("unexpected condition in MultiProps->to_isatab");
	      }
	    } else {
	      # if not at the end of the multiprop sentence it must be an ontology term value
	      $characteristics->{$heading}{value} = $term2->name;
	      $characteristics->{$heading}{term_source_ref} = $term2->dbxref->db->name;
	      $characteristics->{$heading}{term_accession_number} = $term2->dbxref->accession;
	    }
	  }
	} else {
	  # simple single term or plain text value with units
	  my $heading = sprintf "%s (%s)", $mprop_type->name, $mprop_type->dbxref->as_string;
	  if (@cvterms == 2) {
	    if (defined $multiprop->value) {
	      $characteristics->{$heading}{value} = $multiprop->value;
	      $characteristics->{$heading}{unit}{value} = $cvterms[1]->name;
	      $characteristics->{$heading}{unit}{term_source_ref} = $cvterms[1]->dbxref->db->name;
	      $characteristics->{$heading}{unit}{term_accession_number} = $cvterms[1]->dbxref->accession;
	    } else {
	      $characteristics->{$heading}{value} = $cvterms[1]->name;
	      $characteristics->{$heading}{term_source_ref} = $cvterms[1]->dbxref->db->name;
	      $characteristics->{$heading}{term_accession_number} = $cvterms[1]->dbxref->accession;
	    }
	  } elsif (defined $multiprop->value) {
	    $characteristics->{$heading}{value} = $multiprop->value;
	  }
	}
      }
    }
  }



  return ($comments, $characteristics);
}


1;
