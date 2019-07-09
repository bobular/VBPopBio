package Bio::Chado::VBPopBio::Util::ISATab;

use strict;
use warnings;
use Bio::Chado::VBPopBio::Util::Functions qw/ordered_hashref/;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(write_extra_sheets);

=head1 NAME

Bio::Chado::VBPopBio::Util::ISATab

=head1 SYNOPSIS

Helper function to write the 'extended ISA-Tab' genotype and phenotype sheets that
are not part of the standard ISA-Tab specification, and so should not go in
Bio::Parser::ISATab

  use Bio::Chado::VBPopBio::Util::ISATab qw/write_extra_sheets/;

=cut

=head2 write_extra_sheets

Introspects the $isatab data structure looking for all the "Raw Data File" values and
prepares the data and writes the files using standard Bio::Parser::ISATab functions.

usage:

  my $isatab = ...;
  my $writer = Bio::Parser::ISATab->new(directory=>$output_directory);
  $writer->write($isatab);
  write_extra_sheets($writer, $isatab);

=cut

sub write_extra_sheets {
  my ($writer, $isatab) = @_;

  #
  # deeply examine $isatab for all assay 'raw_data_files'
  # and search for $isa_data->{assays}{$assay_name}{genotypes}
  # or $isa_data->{assays}{$assay_name}{phenotypes}
  # and for each raw_data_filename, make a copy of the data for $writer->write_study_or_assay()
  #
  my %filename2assays2genotypes;
  my %filename2assays2phenotypes;

  foreach my $study_assay (@{$isatab->{studies}[0]{study_assays}}) {
    foreach my $sample (keys %{$study_assay->{samples}}) {
      foreach my $assay (keys %{$study_assay->{samples}{$sample}{assays}}) {
	my $assay_isa = $study_assay->{samples}{$sample}{assays}{$assay};
	foreach my $g_or_p_filename ($assay_isa->{raw_data_files} ? keys($assay_isa->{raw_data_files}) : ()) {
	  if ($assay_isa->{genotypes}) {
	    $filename2assays2genotypes{$g_or_p_filename}{assays} //= ordered_hashref();
	    $filename2assays2genotypes{$g_or_p_filename}{assays}{$assay}{genotypes} = $assay_isa->{genotypes};
	  }
	  if ($assay_isa->{phenotypes}) {
	    $filename2assays2phenotypes{$g_or_p_filename}{assays} //= ordered_hashref();
	    $filename2assays2phenotypes{$g_or_p_filename}{assays}{$assay}{phenotypes} = $assay_isa->{phenotypes};
	  }
	}
      }
    }
  }
  foreach my $g_filename (keys %filename2assays2genotypes) {
    $writer->write_study_or_assay($g_filename, $filename2assays2genotypes{$g_filename},
				  ordered_hashref(
				   'Genotype Name' => 'reusable node',
				   'Type' => 'attribute',
				  ));
  }
  foreach my $p_filename (keys %filename2assays2phenotypes) {
    $writer->write_study_or_assay($p_filename, $filename2assays2phenotypes{$p_filename},
				  ordered_hashref(
				   'Phenotype Name' => 'reusable node',
				   'Observable' => 'attribute',
				   'Attribute' => 'attribute',
				   'Value' => 'attribute',
				  ));
  }

}

1;
