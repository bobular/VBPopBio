package Bio::Chado::VBPopBio::Result::Cvterm;

use Carp;
use base 'Bio::Chado::Schema::Result::Cv::Cvterm';
__PACKAGE__->load_components('+Bio::Chado::VBPopBio::Util::Subclass');
__PACKAGE__->subclass({
		       dbxref => 'Bio::Chado::VBPopBio::Result::Dbxref',
		       cvtermpath_subjects => 'Bio::Chado::VBPopBio::Result::Cvtermpath',
		       cvtermpath_objects => 'Bio::Chado::VBPopBio::Result::Cvtermpath',
		       cvterm_dbxrefs => 'Bio::Chado::VBPopBio::Result::Linker::CvtermDbxref',
		       # we could have a huge list of relationships here
		       # e.g. nd_experiments, stocks...
                       # but let's add them if/as we need them
		      });

# this is needed because the BCS Cvterm result class manually
# calls resultset_class() so we have to do the same here
# to avoid runtime warnings and incorrect assignment of the cvterm resultset
__PACKAGE__->resultset_class('Bio::Chado::VBPopBio::ResultSet::Cvterm');

=head1 NAME

Bio::Chado::VBPopBio::Result::Cvterm

=head1 SYNOPSIS

Cv::Cvterm object with extra convenience functions

=head1 SUBROUTINES/METHODS

=head2 as_data_structure

returns a json-like hashref of arrayrefs and hashrefs

=cut

sub as_data_structure {
  my ($self) = @_;
  return {
	  name => $self->name,
	  accession => $self->dbxref->as_string,
	 };
}

=head2 direct_parents

 Usage: $self->direct_parents
 Desc:  get only the direct parents of the cvterm (from the cvtermpath)
 Ret:   L<Bio::Chado::Schema::Result::Cv::Cvterm>
 Args:  none
 Side Effects: none

NOTE: This method requires that your C<cvtermpath> table is populated.
      IT WILL NOT BE AUTOMATICALLY POPULATED - whereas recursive_parents will do this for you.

=cut

sub direct_parents {
    my $self = shift;
    return
        $self->search_related(
            'cvtermpath_subjects',
            {
                pathdistance => 1,
            } )->search_related( 'object');
}

=head2 direct_children

 Usage: $self->direct_children
 Desc:  find only the direct children of your term
 Ret:   L<Bio::Chado::Schema::Result::Cv::Cvterm>
 Args:  none
 Side Effects: none

NOTE: This method requires that your C<cvtermpath> table is populated.
      IT WILL NOT BE AUTOMATICALLY POPULATED - whereas recursive_parents will do this for you.

=cut

sub direct_children {
  my $self = shift;
  return
    $self->search_related(
			  'cvtermpath_objects',
			  {
			   pathdistance => 1,
			  }
			 )->search_related('subject');
}

=head2 recursive_parents

wrapper around Bio::Chado::Schema version to trigger on-the-fly cvtermpath filling

=cut

sub recursive_parents {
  my ($self) = @_;
  $self->populate_cvtermpath_parents_if_needed;
  return $self->SUPER::recursive_parents;
}


=head2 recursive_children

Not implemented yet because we don't have a
populate_cvtermpath_children_if_needed recursion routine (potentially
memory hogging!)

=cut

sub recursive_children {
  confess "not implemented";
}


=head2 recursive_parents_same_ontology

see recursive_parents from Bio::Chado::Schema, but with an additional filter to
restrict terms to the same "dbxref prefix" (e.g. MIRO) as the "self" term.

=cut

sub recursive_parents_same_ontology {
  my ($self) = @_;
  return $self->recursive_parents->search
    ({ 'db.db_id' => $self->dbxref->db->id },
     { join => { dbxref => 'db' },
       prefetch => { dbxref => 'db' },
     });
}

=head2 has_child

returns true if argument is child of self

=cut

sub has_child {
  my ($self, $child) = @_;
  $child->populate_cvtermpath_parents_if_needed;
  my $search = $self->search_related('cvtermpath_objects', { subject_id => $child->id,
							     pathdistance => { '>' => 0 } });
  return $search->count();
}

=head2 populate_cvtermpath_parents_if_needed

do the recursive descent if no direct parents are already in cvtermpath

crudely checks to see if ANY parents are in cvtermpath, regardless of
cvtermpath.type (which we then set to relationships_to_follow...)

follows relationships between ontologies (terms with different dbxref.db.name)

=cut

sub populate_cvtermpath_parents_if_needed {
  my ($self) = @_;
  if ($self->direct_parents->count() == 0) {
    _recurse($self->result_source->schema, [ $self ], 1);
  }
}

=head2 _recurse

private recursion routine - mostly borrowed from GMOD's make_cvtermpath.pl

http://gmod.svn.sourceforge.net/viewvc/gmod/schema/trunk/chado/bin/make_cvtermpath.pl?revision=25288&view=markup

=cut

sub _recurse {
  my ($schema, $subjects, $dist) = @_;
  my $rel_type = $schema->types->relationships_to_follow;
  my $rel_types = [ split /,/, $rel_type->definition ];
  my $rel_type_id = $rel_type->id;
  my $paths = $schema->resultset('Cvtermpath');

  my $subject = $subjects->[-1];

  my $objects = $subject->cvterm_relationship_subjects->
    search({ 'type.name' => { -in => $rel_types } }, { join => 'type' })->search_related('object');

  while (my $object = $objects->next) {
    my $tdist = $dist;
    foreach my $s (@$subjects){
      # warn $s->name." distance $tdist to ".$object->name."\n";
      $paths->find_or_create( {
			       subject_id => $s->id,
			       object_id => $object->id,
			       cv_id => $s->cv->id,
			       pathdistance => $tdist,
			       type_id => $rel_type_id,
			      } );

      $paths->find_or_create( {
			       subject_id => $object->id,
			       object_id => $s->id,
			       cv_id => $object->cv->id,
			       pathdistance => -$tdist,
			       type_id => $rel_type_id,
			      } );
      $tdist--;
    }
    _recurse($schema, [ @$subjects, $object ], $dist+1);
  }
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

1; # End of Bio::Chado::VBPopBio::Result::Cvterm
